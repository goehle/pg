=head1 NAME

PythonInterpreter - An object which will run and print python code.  

=head1 DESCRIPTION

This runs and prints python code.  

=head1 SYNOPSIS

=cut

use strict;
use AnswerHash;
use PGcore;

package Python::PythonCode;
use base qw(Python::PythonInterpreter);

sub ans_box {shift; pgCall('ans_box',@_)}

sub cmp {
  my $self = shift;
  my $ans = new AnswerEvaluator();

  $ans->ans_hash( 	
		 correct_ans       => $self->stdout,
		 type              => 'string_literal',
		);
  
  # remove all pre filters
  $ans->install_pre_filter('reset');

  $ans->install_evaluator(
    sub {
        my $ans_hash = shift;
	my $pgpath = shift;
	$ans_hash->{_filter_name} = "compare code output";
	$ans_hash->{original_student_ans} =
	  $ans_hash->{original_student_ans} // '';

	my $studentCode =
	  Python::PythonCode->new($pgpath,
				  $ans_hash->{original_student_ans});

	$studentCode->evaluate();

	$ans_hash->{score} = $studentCode->stdout eq $ans_hash->{correct_ans};

	$ans_hash->{correct_ans} = $ans_hash->{correct_ans};
	$ans_hash->{student_ans} = $ans_hash->{original_student_ans};
	$ans_hash->{preview_latex_string} = $studentCode->stdout();
	$ans_hash->{ans_message} = $studentCode->stderr();
	return $ans_hash;
      },
      $self->{pgpath});
  
  # set up post filters to correctly format results in html
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
      
      $string = $ans_hash->{'preview_latex_string'};
      $string = '<pre>'.PGcore::encode_pg_and_html($string).'</pre>';
      $ans_hash->{preview_latex_string} = $string;

      $string = $ans_hash->{ans_message};
      if ($string) {
	$string =~ s/^.*File "jailed_code"[\S ]*\n//s;
	$string = '<pre>'.PGcore::encode_pg_and_html($string).'</pre>';
	$ans_hash->{ans_message} = $string;
      }
      
      $string = $ans_hash->{'correct_ans'};
      $string = '<pre>'.PGcore::encode_pg_and_html($string).'</pre>';
      $ans_hash->{'correct_ans'} = $string;
      
      return $ans_hash;
    });
  
  return $ans;
}

1;
