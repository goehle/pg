######################################################################
##
##  Functions for creating tables of various kinds
##
##

my ($BCODE,
    $ECODE,
    $BPCODE,
    $EPCODE,
    $I,
    $II,
    $III,
    $IIII,
    );

sub _WCUCSmacros_init {
    loadMacros('text2PG.pl');   

    if (!$main::WCUCSHeaderSet) {
	main::HEADER_TEXT(<<'END_HEADER_TEXT');
	<script src="/webwork2_files/js/vendor/codeprettify/run_prettify.js" language="javascript"></script>
        <script type="text/javascript">
        $(function() {
            $('.pgml_code').addClass('prettyprint');
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

sub format_string {
    my $string = shift;
    
    $string =~ s/\\n/\n/g;

    if ($main::displayMode eq 'TeX' || 
	$main::displayMode eq 'Latex2HTML') {
	$string =~ s/\n/\newline/g;
    } elsif ($main::displayMode =~ /^HTML/){
	$string =~ s/\n/<br>/g;
	$string =~ s/&#10;/<br>/g;
	$string =~ s/ /&nbsp;/;
    }

    return $string;
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
