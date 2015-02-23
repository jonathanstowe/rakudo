use lib 't/04-nativecall';
use CompileTestLib;
use lib 'lib';
use NativeCall;
use Test;

plan 17;

compile_test_lib('13-union');

class Onion is repr('CUnion') {
    has long   $.l;
    has uint32 $.i;
    has uint16 $.s;
    has uint8  $.c;
}

class MyStruct is repr('CStruct') {
    has long   $.long;
    has num64  $.num;
    has int8   $.byte;
    has Onion  $.onion;
    has num32  $.float;
    has CArray $.arr;

    method init() {
        $!long = 42;
        $!byte = 7;
        $!num = -3.7e0;
        $!float = 3.14e0;
        my $arr := CArray[long].new();
        $arr[0] = 1;
        $arr[1] = 2;
        $!arr := $arr;
    }
}

# Workaround a Rakudo-bug where $!arr := CArray[long].new() won't work if $.arr
# is declared as type CArray[long].
class MyStruct2 is repr('CStruct') {
    has long         $.long;
    has num          $.num;
    has int8         $.byte;
    has Onion        $.onion;
    has num32        $.float;
    has CArray[long] $.arr;
}

sub ReturnMyStruct() returns MyStruct2 is native('./13-union') { * }
sub SizeofMyStruct() returns int32     is native('./13-union') { * }

is nativesizeof(MyStruct), SizeofMyStruct(), 'sizeof(MyStruct)';

# Perl-side tests:
my MyStruct $obj .= new;
$obj.init;

is $obj.long,         42,     'getting long';
is_approx $obj.num,  -3.7e0,  'getting num';
is $obj.byte,         7,      'getting int8';
is_approx $obj.float, 3.14e0, 'getting num32';
is $obj.arr[1],       2,      'getting CArray and element';

# C-side tests:
my $cobj = ReturnMyStruct;

is $cobj.long,          17,     'getting long from C-created struct';
is_approx $cobj.num,    4.2e0,  'getting num from C-created struct';
is $cobj.byte,          13,     'getting int8 from C-created struct';
is_approx $cobj.float, -6.28e0, 'getting num32 from C-created struct';
is $cobj.arr[0],        2,      'C-created array member, elem 1';
is $cobj.arr[1],        3,      'C-created array member, elem 2';
is $cobj.arr[2],        5,      'C-created array member, elem 3';

is $cobj.onion.l, 1 +< 30 +| 1 +< 14 +| 1 +< 6, 'long in union';
is $cobj.onion.i, 1 +< 30 +| 1 +< 14 +| 1 +< 6, 'int in union';
is $cobj.onion.s, 1 +< 14 +| 1 +< 6,            'short in union';
is $cobj.onion.c, 1 +< 6,                       'char in union';

# vim:ft=perl6
