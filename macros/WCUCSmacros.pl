################################################################################
# WeBWorK Online Homework Delivery System
# Copyright © 2000-2007 The WeBWorK Project, http://openwebwork.sf.net/
# $CVSHeader$
# 
# This program is free software; you can redistribute it and/or modify it under
# the terms of either: (a) the GNU General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any later
# version, or (b) the "Artistic License" which comes with this package.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See either the GNU General Public License or the
# Artistic License for more details.
################################################################################

=head1 NAME

WCUCSmacros.pl - Macros to use with the Python code system and for writing
computer science problems.

=head1 DESCRIPTION

These macros are for writing Python based computer science programs.  They 
make use of the codejail system from EDX (L<https://github.com/edx/codejail>).
There are two main objects, the first takes in Python code and the answer is
the (stdout) output of the Python code.  The other takes in Python code and
the answer is student Python code which is correct if it produces the same 
output as the instructor python code.  There are also some macros for randomly
generating variable names and strings.  

=head2 INSTALLATION

Before these macros can be used the codejail system has to be set up 
correctly.  This is a one time setup which needs to be done on the server

1. Install inline python: C<cpanm Inline::Python>

2. Create a virtualenv

=begin code

sudo virtualenv --python=python3 /wwsandbox

=end code

You don't have to use python3, but all of the WCU CS problems were written
for python3 and beacause the python code is included in the pg file, 
they will not be compatible with python2.  

3. Add the sandbox user

=begin code

sudo addgroup sandbox
sudo adduser --disabled-login sandbox --ingroup sandbox

=end code

4.  Let the web server run the sandboxed Python as sandbox.  Create the file
C</etc/sudoers.d/01-sandbox> and add the following (using C<visudo>) 
where C<SANDBOX_CALLER> is the apache web user (e.g. apache or www-data)

=begin code

<SANDBOX_CALLER> ALL=(sandbox) SETENV:NOPASSWD:/wwsandbox/bin/python
<SANDBOX_CALLER> ALL=(sandbox) SETENV:NOPASSWD:/usr/bin/find
<SANDBOX_CALLER> ALL=(ALL) NOPASSWD:/usr/bin/pkill

=end code

5.  Edit an AppArmor profile. This is a text file specifying the limits on 
the sandboxed Python executable. Create the file 
C</etc/apparmor.d/wwsandbox.bin.python> and add the following. Note: If you
are not using python3 then you should change python3 to whatever non-symlink
command is eventually being run.  

=begin code

#include <tunables/global>

/wwsandbox/bin/python3 {
    #include <abstractions/base>
    #include <abstractions/python>

    /wwsandbox/** mr,
    # If you have code that the sandbox must be able to access, add lines
    # pointing to those directories:
    #/the/path/to/your/sandbox-packages/** r,

    /tmp/codejail-*/ wrix,
    /tmp/codejail-*/** wrix,
}

=end code

Then parse the profiles to activate them 

=begin code

sudo apparmor_parser /etc/apparmor.d/wwsandbox.bin.python

=end code

=head2 USAGE

You create a code object using either C<PythonOutput()> or C<PythonCode()>.  
The first argument to the function should be the code.  The following 
arguments can be provided as well: 

=item files

This is a list of pairs, each pair is a filename and a bytestring of contents 
to write into that file.  These files will be created in a jailed tmp 
directory and cleaned up automatically.  No subdirectories are supported in 
the filename.  The files will be available to the jailed code in its current
directory.

=item argv

This is an array ref of command-line arguments which will be provided to the 
jailed code. 

=item stdin

This is a string, the data to provide as the stdin for the process.

Once you have created the object you can use the following methods

=item options

This can be used to get the options listed above and also to set them. 

=item code

This can be used to get the code or to set it.  

=item evaluate

This runs the jailed code.  It returns the status of the jailed code.  The
stdout and stderr of the code are stored in the stdout and stderr attributes

=item status

This returns the status of evaluated code. 

=item stdout

This returns the stdout output of evaluated code. 

=item stderr

This returns the stderr output of evaluated code. 

=item cmp

This returns a comparator for the object.  For C<PythonOutput> the students
answer is compared to the stdout of the code.  For C<PythonCode> the students
answer is run as python code and the two outputs are compared for equality.  

=head2 EXAMPLES

The following problem prints out some basic python code and asks students
to provide the otput of the python code.  The output is checked exactly, 
including the number of spaces. 

=begin code
 
 DOCUMENT();      
 loadMacros(
    "PGstandard.pl", 
    "PGML.pl",
    "WCUCSmacros.pl",
 );
 TEXT(beginproblem());
 $showPartialCorrectAnswers = 1;
 $code = PythonOutput(<<EOS);
 var = 3
 print('The answer is: ',var)
 EOS
 $code->evaluate();
 WARN_MESSAGE($code->stderr) if $code->stderr;
 BEGIN_PGML
 *Enter the output of the code below:*   
 Code:   
 ```[@ $code->code() @]``` 
 Answer:   
 [____]{$code->cmp}{80}
 END_PGML
 BEGIN_PGML_SOLUTION
 Output:   
 :   [@ $code->stdout() @]
 END_PGML_SOLUTION
  
 ENDDOCUMENT();

=end code

Note that we are using PGML to generate the problem text.  PGML is a good 
choice for these types of problems because it is easy to write code 
blocks using C<```code```> and its easy to make preformatted text by writing
C<:  preformated>.  When making answer blanks do either C<[_____]{$code->cmp}>
for answer rules or C<[_____]*{$code->cmp}> for answer boxes.  

This example asks students to provide the output of a snippet of Python code. 
The code is provided with stdinput as well as arguements which are part
of the output.  Notice that the argv list is a reference to an array of strings.

=begin code
 
 DOCUMENT();      
 loadMacros(
    "PGstandard.pl", 
    "PGML.pl",
    "WCUCSmacros.pl",
 );
 TEXT(beginproblem());
 $showPartialCorrectAnswers = 1;
 $code = PythonOutput(<<EOS);
 import sys
 var = input()
 print('The input is: ',var)
 print('The second argument is: ', sys.argv[2] )
 EOS
 $stdin = "Hello World";
 $argv = ['Arg1', 'Arg2'];
 $code->options(stdin=>$stdin, argv=>$argv);
 $code->evaluate();
 WARN_MESSAGE($code->stderr) if $code->stderr;
 BEGIN_PGML
 *Enter the output of the code below:*   
  Code:   
 ```[@ $code->code() @]```
 Input: 
 :   [$stdin]
 Arguments:   
 :   [@ join(', ',@$argv) @]
 Answer:   
 [____]*{$code->cmp}{80}
 END_PGML
 BEGIN_PGML_SOLUTION
 Output:   
 :   [@ $code->stdout() @]
 END_PGML_SOLUTION
 ENDDOCUMENT();        

=end code

In this example a file with name file is created containing the text Hello 
World.  The Python code opens the file and reads and prints the content. 

=begin code 
 
 DOCUMENT();      
 loadMacros(
    "PGstandard.pl", 
    "PGML.pl",
    "WCUCSmacros.pl",
 );
 TEXT(beginproblem());
 $showPartialCorrectAnswers = 1;
 $filename = 'file';
 $filetext = 'Hello World';
 $code = PythonOutput(<<EOS);
 f = open('$filename')
 print('The files contents are: ', f.read())
 EOS
 $code->options(files=>[[$filename,$filetext]]);
 $code->evaluate();
 WARN_MESSAGE($code->stderr) if $code->stderr;
 BEGIN_PGML
 *Enter the output of the code below:*   
  Code:   
  ```[@ $code->code() @]```
  Filetext:  
 :   [$filetext]
 Answer:   
 [____]{$code->cmp}{80}
 END_PGML
 BEGIN_PGML_SOLUTION
 Output:   
 :   [@ $code->stdout() @]
 END_PGML_SOLUTION
 ENDDOCUMENT();    

=end code

In this example students are asked to create code which prints the described
output.  

=begin code
 
 DOCUMENT();      
 loadMacros(
    "PGstandard.pl",  
    "PGML.pl",
    "WCUCSmacros.pl",
 );
 TEXT(beginproblem());
 $showPartialCorrectAnswers = 1;
 $code = PythonCode(<<EOS);
 for i in range(0,10):
     print('The number is:', i)
 EOS
 $code->evaluate();
 WARN_MESSAGE($code->stderr) if $code->stderr;
 BEGIN_PGML
 *Enter code to produce the following output*  
 Output:  
 :   [@ $code->stdout() @] 
 Answer:   
 [_______]*{$code->cmp}
 END_PGML
 BEGIN_PGML_SOLUTION
 Code:
 ```[@ $code->code @]```
 END_PGML_SOLUTION
 ENDDOCUMENT();        

=end code

=cut

sub _WCUCSmacros_init {
    loadMacros('text2PG.pl');   

    if (!$main::WCUCSHeaderSet) {
	main::HEADER_TEXT(<<'END_HEADER_TEXT');
	<script src="/webwork2_files/js/vendor/codeprettify/run_prettify.js" language="javascript"></script>
        <script type="text/javascript">
        $(function() {
            $('code.pgml').addClass('prettyprint');
        });
        </script>
END_HEADER_TEXT

	$main::WCUCSHeaderSet = 1;
    }

}; # don't reload this file

sub PythonOutput {
  return new Python::PythonOutput($envir{pgDirectories}->{lib}, @_);
}

sub PythonCode {
  return new Python::PythonCode($envir{pgDirectories}->{lib}, @_);
}

sub random_word {
    return $word_list[random(0,$#word_list)];
}

sub random_sentence {
    return $sentence_list[random(0,$#sentence_list)];
}

sub random_phrase {
    return $phrase_list[random(0,$#phrase_list)];
}

@word_list= qw(abandoned apple bevelled butter ceres 
chicken despise depot eighth eject 
fatigue football gargoyle ghoulish hamper 
house infant ingest jack joint 
klaxon knead library lone meat
moon napalm north opal order
pause premonition queen quality roast
remand steel scene turnip trunk 
ulcer unnerve vent vanish water
world xavier young yawn zoom );

@python_keywords = qw( and       del       from      not       while
as        elif      global    or        with
assert    else      if        pass      yield
break     except    import    print
class     exec      in        raise
continue  finally   is        return 
def       for       lambda    try );

@java_keywords = qw( abstract 	continue 	for 	new 	switch
assert 	default 	goto 	package 	synchronized
boolean 	do 	if 	private 	this
break 	double 	implements 	protected 	throw
byte 	else 	import 	public 	throws
case 	enum 	instanceof 	return 	transient
catch 	extends 	int 	short 	try
char 	final 	interface 	static 	void
class 	finally 	long 	strictfp 	volatile
const 	float 	native 	super 	while  );

@sentence_list = (
    'The choral decays below the juice!',
    'Past the force fiddles the gateway.',
    'Its whim leans past the corrupt distress.',
    'The marketing of narrative authenticity interrogates the discourse of post-Jungian analysis.',
    'The discourse of the abyss may be seen as the ideology of exoticism.',
    'The soil sizes the crew.',
    'The piano punts!',
    'The museum triumphs!',
    'The social project confuses a boiled bankrupt.',
    'How will every climbing peanut lose?',
    'The east reaches a signal.',
    'The money emerges next to the wallet!',
    'When will the module invert a skilled comparison?',
    'How will butter apologize?',
    'A leaf fishes the razor.',
    'When can the calm safeguard an immoral energy?',
    'Why can the dog dance within the moon?',
    'The archive cautions opposite the cable.',
    'Her confident scholar errs in the heart.',
    'Over the dishonest fuel finishes your condemning attendant.');

@phrase_list = (
    'Eat your foot.',
    'I hate the green flashing light.', 
    'Hello. I have the urge to kill.', 
    'DO NOT DISTURB, evil genius at work.',
    'Rubber ducks are planning world domination!',
    'I know kung fu and 50 other dangerous words.',
    'Love your enemies, it makes them angry.', 
    'Do not mess with me! I have a stick!', 
    'Go away, evil Mr. Scissors!',
    'Ha ha! I do not get it.',
    'It is much funnier now that I get it.', 
    'Come to the dark side. We have cookies.', 
    'The decision is maybe and that’s final!', 
    'I am pretending to be a tomato.', 
    'Never put a cat on your head.', 
    'Do not eat my foot!', 
    'The banana has legs!', 
    'Do not worry, I was born this way.', 
    'We are so skilled!',
    );



1;
