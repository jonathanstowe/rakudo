my class RoleToRoleApplier {
    method apply($target, @roles) {
        # Ensure we actually have something to appply.
        unless +@roles {
            return [];
        }

        # Aggregate all of the methods sharing names, eliminating
        # any duplicates (a method can't collide with itself).
        my %meth_info;
        my %meth_providers;
        my %priv_meth_info;
        my %priv_meth_providers;
        for @roles {
            my $role := $_;
            sub build_meth_info(%methods, %meth_info_to_use, %meth_providers_to_use) {
                for %methods {
                    my $name := $_.key;
                    my $meth := $_.value;
                    my @meth_list;
                    my @meth_providers;
                    if nqp::existskey(%meth_info_to_use, $name) {
                        @meth_list := %meth_info_to_use{$name};
                        @meth_providers := %meth_providers_to_use{$name};
                    }
                    else {
                        %meth_info_to_use{$name} := @meth_list;
                        %meth_providers_to_use{$name} := @meth_providers;
                    }
                    my $found := 0;
                    for @meth_list {
                        if $meth =:= $_ {
                            $found := 1;
                        }
                        elsif nqp::can($meth, 'id') && nqp::can($_, 'id') {
                            $found := $meth.id == $_.id;
                        }
                    }
                    unless $found {
                        @meth_list.push($meth);
                        @meth_providers.push($role.HOW.name($role));
                    }
                }
            }
            build_meth_info($_.HOW.method_table($_), %meth_info, %meth_providers);
            build_meth_info($_.HOW.submethod_table($_), %meth_info, %meth_providers)
                if nqp::can($_.HOW, 'submethod_table');
            build_meth_info($_.HOW.private_method_table($_), %priv_meth_info, %priv_meth_providers)
                if nqp::can($_.HOW, 'private_method_table');
        }

        # Also need methods of target.
        my %target_meth_info := $target.HOW.method_table($target);

        # Process method list.
        for %meth_info {
            my $name := $_.key;
            my @add_meths := %meth_info{$name};

            # Do we already have a method of this name? If so, ignore all of the
            # methods we have from elsewhere.
            unless nqp::existskey(%target_meth_info, $name) {
                # No methods in the target role. If only one, it's easy...
                if +@add_meths == 1 {
                    $target.HOW.add_method($target, $name, @add_meths[0]);
                }
                else {
                    # Find if any of the methods are actually requirements, not
                    # implementations.
                    my @impl_meths;
                    for @add_meths {
                        my $yada := 0;
                        try { $yada := $_.yada; }
                        unless $yada {
                            @impl_meths.push($_);
                        }
                    }

                    # If there's still more than one possible - add to collisions list.
                    # If we got down to just one, add it. If they were all requirements,
                    # just choose one.
                    if +@impl_meths == 1 {
                        $target.HOW.add_method($target, $name, @impl_meths[0]);
                    }
                    elsif +@impl_meths == 0 {
                        $target.HOW.add_method($target, $name, @add_meths[0]);
                    }
                    else {
                        $target.HOW.add_collision($target, $name, %meth_providers{$name});
                    }
                }
            }
        }

        # Process private method list.
        if nqp::can($target.HOW, 'private_method_table') {
            my %target_priv_meth_info := $target.HOW.private_method_table($target);
            for %priv_meth_info {
                my $name := $_.key;
                my @add_meths := %priv_meth_info{$name};
                unless nqp::existskey(%target_priv_meth_info, $name) {
                    if +@add_meths == 1 {
                        $target.HOW.add_private_method($target, $name, @add_meths[0]);
                    }
                    else {
                        # Find if any of the methods are actually requirements, not
                        # implementations.
                        my @impl_meths;
                        for @add_meths {
                            my $yada := 0;
                            try { $yada := $_.yada; }
                            unless $yada {
                                @impl_meths.push($_);
                            }
                        }

                        # If there's still more than one possible - add to collisions list.
                        # If we got down to just one, add it. If they were all requirements,
                        # just choose one.
                        if +@impl_meths == 1 {
                            $target.HOW.add_private_method($target, $name, @impl_meths[0]);
                        }
                        elsif +@impl_meths == 0 {
                            # any of the method stubs will do
                            $target.HOW.add_private_method($target, $name, @add_meths[0]);
                        }
                        else {
                            $target.HOW.add_collision($target, $name, %priv_meth_providers{$name}, :private(1));
                        }
                    }
                }
            }
        }

        # Compose multi-methods; need to pay attention to the signatures.
        my %multis_by_name;
        my %multis_required_by_name;
        for @roles -> $role {
            my $how := $role.HOW;
            if nqp::can($how, 'multi_methods_to_incorporate') {
                for $how.multi_methods_to_incorporate($role) {
                    my $name := $_.name;
                    my $to_add := $_.code;
                    my $yada := 0;
                    try { $yada := $to_add.yada; }
                    if $yada {
                        %multis_required_by_name{$name} := []
                            unless %multis_required_by_name{$name};
                        nqp::push(%multis_required_by_name{$name}, $to_add);
                    }
                    else {
                        if %multis_by_name{$name} -> @existing {
                            # A multi-method can't conflict with itself.
                            my int $already := 0;
                            for @existing {
                                if $_[1] =:= $to_add {
                                    $already := 1;
                                    last;
                                }
                            }
                            nqp::push(@existing, [$role, $to_add]) unless $already;
                        }
                        else {
                            %multis_by_name{$name} := [[$role, $to_add],];
                        }
                    }
                }
            }
        }

        # Look for conflicts, and compose non-conflicting.
        for %multis_by_name {
            my $name := $_.key;
            my @cands := $_.value;
            my @collisions;
            for @cands -> $c1 {
                my @collides;
                for @cands -> $c2 {
                    unless $c1[1] =:= $c2[1] {
                        if Perl6::Metamodel::Configuration.compare_multi_sigs($c1[1], $c2[1]) {
                            for ($c1, $c2) {
                                nqp::push(@collides, $_[0].HOW.name($_[0]));
                            }
                            last;
                        }
                    }
                }
                if @collides {
                    $target.HOW.add_collision($target, $name, @collides, :multi($c1[1]));
                }
                else {
                    $target.HOW.add_multi_method($target, $name, $c1[1]);
                }
            }
        }

        # Pass on any unsatisfied requirements (note that we check for the
        # requirements being met when applying the summation of roles to a
        # class, so we can avoid duplicating that logic here.)
        for %multis_required_by_name {
            my $name := $_.key;
            for $_.value {
                $target.HOW.add_multi_method($target, $name, $_);
            }
        }

        # Now do the other bits.
        for @roles {
            my $how := $_.HOW;

            # Compose is any attributes, unless there's a conflict.
            my @attributes := $how.attributes($_, :local(1));
            for @attributes {
                my $add_attr := $_;
                my $skip := 0;
                my @cur_attrs := $target.HOW.attributes($target, :local(1));
                for @cur_attrs {
                    if $_ =:= $add_attr {
                        $skip := 1;
                    }
                    else {
                        if $_.name eq $add_attr.name {
                            nqp::die("Attribute '" ~ $_.name ~ "' conflicts in role composition");
                        }
                    }
                }
                unless $skip {
                    $target.HOW.add_attribute($target, $add_attr);
                }
            }
 
            # Any parents can also just be copied over.
            if nqp::can($how, 'parents') {
                my @parents := $how.parents($_, :local(1));
                for @parents {
                    $target.HOW.add_parent($target, $_);
                }
            }
        }

        1;
    }
}
