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

PythonCode - An object which will run python code and compare the 
output of the given code to the output of student provided code. 

=head1 DESCRIPTION

This object takes in Python code and runs it, capturing the output. When used
as a comaprator it takes in student Python code, runs it, and compares the
output of the student code to the output of the correct code.  You can also
set up tests which test the student code against the correct code using a
variety of pre-defined inputs.  

=head1 SYNOPSIS

=cut

use strict;
use AnswerHash;
use PGcore;

package Python::PythonCode;
use base qw(Python::PythonInterpreter);

sub ans_box {shift; pgCall('ans_box',@_)}

sub tests {
  my $self = shift;
  if (@_ && !defined($self->{tests})) {
    $self->{tests} = [@_];
  } elsif (@_) {
    push @{$self->{tests}}, @_;
  }

  return $self->{tests};
}

sub cmp {
  my $self = shift;
  my $ans = new AnswerEvaluator();

  $ans->ans_hash(
		 correct_ans => $self->code,
		 correct_ans_latex_string => $self->stdout,
		 type              => 'string_literal',
		);

  $ans->install_pre_filter('reset');
  
  $ans->install_evaluator(
    sub {
        my $ans_hash = shift;
	my $pgpath = shift;
	my $run_pylint = shift;
	
	$ans_hash->{_filter_name} = "compare code output";

	# we make sure that the student code is non empty so that
	# the evaluator doesn't try to run the first "argument"
	my $studentCode =
	  Python::PythonCode->new({pg_lib => $pgpath,
				   run_pylint => $run_pylint},
				  $ans_hash->{original_student_ans} ||
				 "1");
	if (defined($self->tests)) {
	  my $n = 0;
	  $ans_hash->{score} = 1;
	  $ans_hash->{correct_ans_latex_string} = '';
	  $ans_hash->{preview_latex_string} = '';
	  $ans_hash->{ans_message} = '';
	  my $correctCode = Python::PythonCode->new({pg_lib=>$pgpath,
						     run_pylint=>0},
						    $self->code);

	  foreach my $options (@{$self->tests()}) {
	    $n++;
	    $studentCode->options(argv => $options->{argv},
				  files => $options->{files},
				  stdin => $options->{stdin});
	    $correctCode->options(argv => $options->{argv},
				  files => $options->{files},
				  stdin => $options->{stdin});

	    $studentCode->evaluate();
	    $correctCode->evaluate();

	    my $result;
	    
	    if ($studentCode->stdout ne $correctCode->stdout) {
	      $ans_hash->{score} = 0;
	      $result = 'failed';
	    } else {
	      $result = 'succeeded';
	    }

	    my $header = "Test $n";
	    my $inputs = '';
	    
	    $inputs .= 'Arguments: '.join(',',@{$options->{argv}})."\n"
	      if $options->{argv};
	    $inputs .= 'Input: '.$options->{stdin}."\n"
	      if $options->{stdin};
	    $inputs .= "Files:\n".join(";\n",
				      map {' Name - '.$_->[0].
					     ', Content - '.$_->[1]}
				      @{$options->{files}})."\n"
	      if $options->{files};

	    $ans_hash->{preview_latex_string} .=
	      $header.' - '.$result."\n".
	      $inputs.
	      "Output:\n".
	      $studentCode->stdout."\n";

	    $ans_hash->{correct_ans_latex_string} .=
	      $header."\n".
	      $inputs.
	      "Output:\n".
	      $correctCode->stdout."\n";
	    
	    if ($studentCode->stderr) {
	      my $string = $studentCode->stderr;
	      $string =~ s/^.*File "jailed_code"[\S ]*\n//s;
	      $ans_hash->{ans_message} .=
		$header."\n".
		"Errors:\n".
		$string."\n";
	    }	    
	  }
	} else {
	  $studentCode->evaluate();
	  $ans_hash->{score} = $studentCode->stdout eq $ans_hash->{correct_ans_latex_string};
	  $ans_hash->{correct_ans_latex_string} = $ans_hash->{correct_ans_latex_string};
	  $ans_hash->{preview_latex_string} = $studentCode->stdout();
	  my $string = $studentCode->stderr;
	  $string =~ s/^.*File "jailed_code"[\S ]*\n//s;
	  $ans_hash->{ans_message} = $string;
	}

	$ans_hash->{student_ans} = $ans_hash->{original_student_ans};
	
	$ans_hash->{comment} = $studentCode->pylint() if $run_pylint;

	return $ans_hash;
      },
      $self->{pgpath},
      $self->{run_pylint});
  
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
