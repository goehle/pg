=head1 NAME

PythonInterpreter - An object which will run and print python code.  

=head1 DESCRIPTION

This runs and prints python code.  

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
    $self->{error} = uc(shift);
  } else {
    return $self->{error};
  }
}


sub cmp {
  my $self = shift;
  my $ans = new AnswerEvaluator();

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
