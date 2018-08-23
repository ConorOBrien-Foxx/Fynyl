# Fynyl

## Installation

```
$ git clone https://github.com/ConorOBrien-Foxx/Fynyl.git
$ fynyl.rb <input>
```

<!--
grep results with: /^ {12}when "(.+?)"/

filter with:

def from_base(base, arr)
    arr.map.with_index { |e, i| e * base**(arr.size - i - 1) }.sum
end
puts STDIN.each_line
.map(&:chomp)
.group_by{|e|e.sub(/^[.:]+/,"")}
.sort_by(&:first)
.map{|k,v|
    v.sort_by{|e|
        a=e.match(/^[.:]+/).to_s
        a.size * 10000 + from_base(2, a.chars.map(&:ord))
    }
}

-->

## Commands

```
command         type        explanation
!               operator    [number n] pushes the factorial of n
                            [block b] executes `b` in the current scope
"               syntax      denotes beginning/end of a string literal; doubling "" escapes a quote
#               meta        composes a block with the next two characters
$               operator    discards the top of the stack
.$              operator    [number N] pops the next N elements on the stack
:$              operator    [number N] pops until there are no more than N elements on the stack       
%               operator    [number a, number b] pushes a mod b
:%              operator    [string s, number n] pops the top N elements, and formats s according to those elements
&               syntax      assigns the top of the stack to the variable indicated by the next token
.&              syntax      assigns the top of the stack to the function indicated by the next token
'               syntax      character literal, like 'a or '~
(               syntax      begins an array, starting a new sub stack
)               syntax      closes an array, pushing the contents of the sub stack onto the previous stack
*               operator    [number a, number b] pushes a * b
                            [number a, block b] executes block b a times in the current scope
                            [block a, number b] executes block a b times in the current scope
                            [number a, string b] pushes b repeated a times
+               operator    [number a, number b] pushes a + b
                            [string a, string b] pushes a concatenated with b
                            [array a, array b] pushes a concatenated with b
,               operator    pops the top two elements into a two-element array
.,              operator    [number N] collects the top N elements into an array
-               operator    [number a, number b] pushes a - b
                            [array a, array b] pushes a without any elements in b
.               syntax      part of a command prefix
/               operator    [number a, number b] pushes a / b
                            [string a, string b] splits a on occurrences of b
                            [array a, number b] splits a into b chunks (if possible)
0-9             syntax      numeric literal start
:               syntax      part of a command prefix
;               operator    [any e] pushes e as a string
<               operator    [any a, any b] pushes a < b
.<              operator    [any a, any b] pushes the lesser of a and b
:<              operator    [any a, any b] pushes a <= b
=               operator    [any a, any b] pushes a == b
:=              operator    [any a, any b] pushes a != b
>               operator    [any a, any b] pushes a > b
.>              operator    [any a, any b] pushes the greater of a and b
:>              operator    [any a, any b] pushes a >= b
?               operator    [number a = 0] pushes a random float in [0, 1)
                            [number a] pushes a random integer in [0, a)
                            [array a] pushes a random element in a
                            [string s] pushes a random character in s
                            [any a, block b] executes b if a is truthy
.?              operator    [array a] pushes a shuffled
@               meta        pushes a block consisting of the next character
A               unassigned
B               unassigned
C               operator    clears the stack
D               operator    [string s] pushes the characters of s
                            [array a] pushes a
                            [number n] pushes the digits of n
E               operator    exits with exit code 0
.E              operator    [number n] exits with exit code n
                            [any a] exits with exit code 0
F               operator    [string s] pushes a function whose content is s
                            [block b] pushes b
G               operator    [number n] pushes n expressed as a fraction
H               unassigned
I               operator    [number n] pushes n expressed as an integer
.I              operator    [any a] isolates a on the stack (i.e. sets the stack to only contain a)
:I              operator    [number N] isolates the top N elements on the stack
J               unassigned
K               unassigned
L               operator    [block b] loops b, i.e. continuously executing it in the current scope
M               operator    [array a] merges the stack with the array, pushing each element in a to the stack
N               unassigned
O               operator    [any a] outputs a to STDOUT without a trailing newline
P               operator    [any a] outputs the representation of a without a trailing newline
Q               unassigned
R               operator    [number a, number b] pushes the inclusive range between a and b
.R              operator    pushes a line of STDIN without a trailing newline
:R              operator    evaluates a line of STDIN in the current scope
..R             operator    pushes a raw line of STDIN
::R             operator    [block b] applies b to each line of STDIN (evaluated)
S               operator    [array a] pushes the sum of a
.:S             operator    debugs the stack
T               operator    [array a] pushes a transposed
U               unassigned
V               meta        [array a, block b] vectorizes b on each atom in a
                            e.g.: ((1 2 3) (4 5 6)) V{2+} is ((3 4 5) (6 7 8))
W               operator    [block c, block b] executes b in the current scope until c yields a falsey value given the stack
X               operator    [array a, base b] converts a from base b to base 10
Y               unassigned
Z               operator    [number n] pushes a range between 0 and n, excluding n
                            [array e] pushes a range between 0 and the size of e, excluding the size
                            [string e] pushes a range between 0 and the size of e, excluding the size
[               operator    [number a] pushes a - 1
\               unassigned
]               operator    [number a] pushes a + 1
                            [string a] pushes the "successor" of a
^               operator    [number a, number b] pushes a to the b power
_               operator    [number n] pushes -n
                            [string s] pushes s in reverse order
                            [array a] pushes a in reverse order
._              operator    reverses the stack's elements
`               unassigned
a               unassigned
b               operator    [any a] pushes a as a boolean
c               operator    [number a] pushes the character whose code point is a
.c              operator    [number a] pushes cos(a)
:c              operator    [number a] pushes arccos(a)
d               operator    duplicates the top element on the stack
e               operator    [string s] evaluates s
f               operator    [array a, block b] folds b over a
                            (empty array works correctly with {+} and {*})
g               operator    [any a] converts a to a floating point number
h               unassigned
i               operator    [number a] pushes a * i (the imaginary unit)
j               operator    [array a, string s] pushes a joined by s
                            [array a] pushes a joined by nothing
k               unassigned
l               unassigned
.l              operator    [string s] loads file s into the current scope
m               meta        [array a, block b] pushes a mapped over b
                            e.g.: _3 3R m| is (3 2 1 0 1 2 3)
.m              meta        [array a, block b] same as `m`, but does not push the resulting array
                            e.g.: 5r .m{"my number is "Oo} outputs:
                            my number is 1
                            my number is 2
                            my number is 3
                            my number is 4
                            my number is 5
n               unassigned
o               operator    [any a] outputs a to STDOUT with a trailing newline
p               operator    [any a] outputs the representation of a with a trailing newline
q               unassigned
r               operator    [number n] pushes a range from 1 to n
.r              operator    reads a line of input from the keyboard
:r              operator    [string s] pushes the contents of a file specified by s
..r             operator    [string s] reads a line of input with a prompt s
s               operator    [string s] pushes the number of characters in s
                            [array a] pushes the number of elements in a
                            [number n] pushes the number of digits in n
t               operator    [array x, array y, block b] tabulates b over x and y
                            e.g.: (1 2 3) (4 5 6) t{*} yields ((4 5 6) (8 10 12) (12 15 18))
u               unassigned
v               meta        [array x, array y, block b] vectorizes b over x and y
                            e.g.: (1 2 3) 3 v+ yields (4 5 6)
w               operator    [block b] while the top value on the stack is truthy, execute b in the current scope
.w              operator    [string c, string p] writes c to file p
x               operator    [number n, number b] converts n to base b
y               operator    pushes the second-to-top member on the stack
z               meta        [array x, array y, block b] zips b across x and y
                            e.g.: ("a" "b" "c") (1 2 3) z{;+} yields ("a1" "b2" "c3")
{               syntax      marks the beginning of a block
|               operator    [number n] pushes the absolute value of n
}               syntax      marks the beginning of a block
~               operator    swaps the top two elements on the stack
                            [when used in as a meta argument] uses the TOS as the function
```
