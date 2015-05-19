######################################################################
##
##  Functions for creating tables of various kinds
##
##

use Inline (safemode =>1);

my ($BCODE,
    $ECODE,
    $I,
    $II,
    $III,
    $IIII,
    );

sub _WCUCSmacros_init {}; # don't reload this file

main::PG_restricted_eval( <<'EOF');
$main::BCODE = BCODE();
$main::ECODE = ECODE();
$main::I = INDENT();
$main::II = IINDENT();
$main::III = IIINDENT();
$main::IIII = IIIINDENT();
EOF

$BCODE = BCODE();
$ECODE = ECODE();
$I = INDENT();
$II = IINDENT();
$III = IIINDENT();
$IIII = IIIINDENT();

sub BCODE { MODES(TeX => '\begin{verbatim} ',  Latex2HTML => '\begin{verbatim} ', HTML => '<CODE>'); };
sub ECODE { MODES( TeX => '\end{verbatim}', Latex2HTML =>  '\end{verbatim}',HTML =>  '</CODE>'); };
sub INDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;'); };
sub IINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };
sub IIINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };
sub IIIINDENT { MODES(TeX => '',  Latex2HTML => '    ', HTML => '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'); };

sub python_cmp {

    my $self = shift;
    my $ans = new AnswerEvaluator;

    $ans->ans_hash(
	type => "code",
	correct_ans => "Undefined",
	correct_value => $self,
	@_,
	);

    $ans->install_evaluator(sub { 			
	my $student = shift;
	my %response_options = @_;
	
	$student->{original_student_ans} = (defined $student->{original_student_ans})? $student->{original_student_ans} :'';
	
	$preamble = <<EOS;
import sys
import errno
import os
import signal
from RestrictedPython import compile_restricted
from RestrictedPython.PrintCollector import PrintCollector
from cStringIO import StringIO

_print_ = PrintCollector
class TimeoutError(Exception):
    pass

class timeout:
    def __init__(self, seconds=1, error_message='Timeout'):
        self.seconds = seconds
        self.error_message = error_message
    def handle_timeout(self, signum, frame):
        raise TimeoutError(self.error_message)
    def __enter__(self):
        signal.signal(signal.SIGALRM, self.handle_timeout)
        signal.alarm(self.seconds)
    def __exit__(self, type, value, traceback):
        signal.alarm(0)

sys.stdout = capturer = StringIO()
sys.stderr = errcapturer = StringIO()

def get_printed():
    return capturer.getvalue()

def get_errors():
    return errcapturer.getvalue()

EOS

        Inline::Python::py_eval($preamble);

	$answer_code = $student->{original_student_ans};
	$answer_code =~ s/\\/\\\\/g;

        eval {
	    Inline::Python::py_eval($answer_code);
        };

	warn $@ if $@;

    
	$output = Inline::Python::py_call_function('__main__','get_printed');
	$errors = Inline::Python::py_call_function('__main__','get_errors');

	$output =~ s/\n/<br>/g;
	$errors =~ s/^.*\n//;

	my $ans_hash = new AnswerHash(
	    'score'=>"0",
	    'correct_ans'=>"Undefined",
	    'student_ans'=>'', #supresses output to original answer field
	    'original_student_ans' => $answer_value,
	    'type' => 'essay',
	    'ans_message'=> $errors,
	    'preview_text_string'=> '',
	    'preview_latex_string'=> $output,
	    );

	return $ans_hash;
			    }
	);
    
    $ans->install_pre_filter('erase') if $self->{ans_name};
    
    return $ans;
}



1;
