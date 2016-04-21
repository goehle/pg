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

Pythondriver - An object which will take student code and provide it as a
module to driver code.  

=head1 DESCRIPTION

For this object the pg code provides "driver" code that should load the 
stuent code as a "student" module.  It can then call and test the student
modules.  The driver code is responsible for printing error messages and 
returning a score.  

=head1 SYNOPSIS

=cut

use strict;
use AnswerHash;
use PGcore;

package Python::PythonDriver;
use base qw(Python::PythonInterpreter);

sub ans_box {shift; pgCall('ans_box',@_)}

sub correct_code {
  my $self = shift;

  if (@_) {
    $self->{correct_code} = shift;
  } else {
    return $self->{correct_code};
  }
}

sub cmp {
  my $self = shift;
  my $ans = new AnswerEvaluator();

  $ans->ans_hash(
		 correct_ans => $self->correct_code,
		 type              => 'string_literal',
		);
  
  $ans->install_evaluator(
    sub {
        my $ans_hash = shift;
	my $pgpath = shift;
	$ans_hash->{_filter_name} = "check driver output";

	# we make sure that the student code is non empty so that
	# the evaluator doesn't try to run the first "argument"
	my $student_code = $ans_hash->{original_student_ans} || "1";

	# add the student code as a file that the driver can import
	my $files = $self->files() // [];
	push @{$files}, ['student.py',$student_code];
	$self->files($files);
	
	$self->evaluate();
	
	$ans_hash->{score} = $self->status;
	$ans_hash->{correct_ans_latex_string} = $self->stdout();
	$ans_hash->{preview_latex_string} = $self->stdout();
	my $string = $self->stderr;
	$string =~ s/^.*File "jailed_code"[\S ]*\n//s;
	$ans_hash->{ans_message} = $string;
	$ans_hash->{student_ans} = $ans_hash->{original_student_ans};
	
	return $ans_hash;
      },
      $self->{pgpath});
  
  # set up post filters to correctly format results in html

  # note the "student_ans" and "correct_ans_latex" strings are what
  # are actually printed in Answer Preview and Correct Answer cells
  # the "original_student_ans" and "correct_ans" strings are the contents
  # of the popovers for those cells, so we include the actual python code
  # there just for kicks.  
  
  $ans->install_post_filter(
    sub {
      my $ans_hash = shift; 
      $ans_hash->{_filter_name} = "clean up strings";
      # tabs mess up the past answer database.  
      $ans_hash->{original_student_ans} =~ s/\t/    /g;
      
      my $string = $ans_hash->{student_ans};
      $string = '<pre><code class="prettyprint">'
	.PGcore::encode_pg_and_html($string)
	.'</code></pre>';
      $ans_hash->{student_ans} = $string;

      my $string = $ans_hash->{correct_ans};
      $string = '<pre><code class="prettyprint">'
	.PGcore::encode_pg_and_html($string)
	.'</code></pre>';
      $ans_hash->{correct_ans} = $string;
      
      $string = $ans_hash->{'preview_latex_string'};
      $string = '<pre>'.PGcore::encode_pg_and_html($string).'</pre>';
      $ans_hash->{preview_latex_string} = $string;

      $string = $ans_hash->{ans_message};
      if ($string) {
	$string = '<pre>'.PGcore::encode_pg_and_html($string).'</pre>';
	$ans_hash->{ans_message} = $string;
      }
      
      $string = $ans_hash->{'correct_ans_latex_string'};
      $string = '<pre>'.PGcore::encode_pg_and_html($string).'</pre>';
      $ans_hash->{'correct_ans_latex_string'} = $string;
      
      return $ans_hash;
    });
  
  return $ans;
}

1;
