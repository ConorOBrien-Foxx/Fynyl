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
#               meta        composes a block with the next two characters
$               operator    discards the top of the stack
.$              operator    [number N] pops the next N elements on the stack
:$              operator    [number N] pops until there are no more than N elements on the stack       
%               operator    [number a, number b] pushes a mod b
:%              operator    [string s, number n] pops the top N elements, and formats s according to those elements
&               meta        assigns the top of the stack to the variable indicated by the next token
(               other       begins an array, starting a new sub stack
)               other       closes an array, pushing the contents of the sub stack onto the previous stack
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
/               operator    [number a, number b] pushes a / b
                            [string a, string b] splits a on occurrences of b
                            [array a, number b] splits a into b chunks (if possible)
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
.?              operator    [array a] pushes a shuffled
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
I               operator    [number n] pushes n expressed as an integer
.I              operator    [any a] isolates a on the stack (i.e. sets the stack to only contain a)
:I              operator    [number N] isolates the top N elements on the stack
L               operator    [block b] loops b, i.e. continuously executing it in the current scope
M               operator    [array a] merges the stack with the array, pushing each element in a to the stack
O               operator    [any a] outputs a to STDOUT without a trailing newline
P               operator    [any a] outputs the representation of a without a trailing newline
R               operator    [number a, number b] pushes the inclusive range between a and b
.R              operator    pushes a line of STDIN without a trailing newline
:R              operator    evaluates a line of STDIN in the current scope
..R             operator    pushes a raw line of STDIN
S               operator    [array a] pushes the sum of a
.:S             operator    debugs the stack
T               operator    [array a] pushes a transposed
V               operator    [array a, block b] vectorizes b on each atom in a
W               operator    [block c, block b] executes b in the current scope until c yields a falsey value given the stack
X               operator    [array a, base b] converts a from base b to base 10
[               operator    [number a] pushes a - 1
]               operator    [number a] pushes a + 1
                            [string a] pushes the "successor" of a
^               
_               
._              
b               
c               
.c              
:c              
d               
e               
f               
g               
i               
j               
.l              
m               
.m              
o               
p               
r               
.r              
:r              
..r             
s               
t               
v               
w               
.w              
x               
y               
z               
|               
~               

```
