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

PythonOutput - An object which asks students to answer the output of given
python code.  

=head1 DESCRIPTION

Given python code this will run the code and when used as a comparator the
students will be correct if they provide the correct output of the python code.
The string comparison is exact and if there is an error the correct answer
is the type of error (e.g. SyntaxError).  

=head1 SYNOPSIS

=cut

use strict;
use AnswerHash;
use PGcore;

package Python::PythonOutput;
use base qw(Python::PythonInterpreter);

sub ans_rule {shift; pgCall('ans_rule',@_)}

sub error {
  my $self = shift;

  if (@_) {
    $self->{error} = shift;
  } else {
    return $self->{error};
  }
}


sub evaluate {
  my $self = shift;

  $self->SUPER::evaluate();

  # We pull off the type of error, if there is one, and use
  # that as the error string. 
  if (!defined($self->error) &&
      $self->stderr =~ /([A-za-z]+Error)/) {
    $self->error($1);
  }
}

sub cmp {
  my $self = shift;
  my $ans = new AnswerEvaluator();
  
  # We use the "error" string preferentially
  my $correct_ans = $self->error // $self->stdout;

  $ans->ans_hash( correct_ans       => $correct_ans,
		  type              => 'string_literal',
		  score             => 0,
		);
  
  # remove all pre filters
  $ans->install_pre_filter('reset');  

  $ans->install_evaluator(
   sub {
     my $ans_hash = shift;
  
     $ans_hash->{_filter_name} = "Evaluator: Compare string answers with eq";
     $ans_hash->{original_student_ans} = $ans_hash->{original_student_ans} // '';

     $ans_hash->{original_student_ans} =~ s/\r//g;
     $ans_hash->{correct_ans} =~ s/\r//g;
     
     chomp($ans_hash->{original_student_ans});
     chomp($ans_hash->{correct_ans});
     
     $ans_hash->{score} =
       ($ans_hash->{original_student_ans} eq $ans_hash->{correct_ans}) ? 1:0;
     
     return $ans_hash;
   });

			    
  
  # set up post filters to correctly format results in html
  $ans->install_post_filter(
    sub {
        my $ans_hash = shift; 
	$ans_hash->{_filter_name} = "clean up strings";
	
	# tabs mess up the past answer database.  
	$ans_hash->{original_student_ans} =~ s/\t/    /g;

	my $string = $ans_hash->{student_ans};
	$string = '<pre>'.PGcore::encode_pg_and_html($string).'</pre>';
	
	$ans_hash->{'preview_text_string'} = $string;
	$ans_hash->{'preview_latex_string'} = $string;
	$ans_hash->{'student_ans'} = $string;
	
	$string = $ans_hash->{'correct_ans'};
	$string = '<pre>'.PGcore::encode_pg_and_html($string).'</pre>';
	$ans_hash->{'correct_ans'} = $string;
	
	return $ans_hash;
      });

  
  return $ans;
}

1;
