use ExtUtils::MakeMaker;
WriteMakefile(
	      NAME	=> 'Cwiki',
	      VERSION => '1.1',
	      ABSTRACT => 'Configurable wiki',
	      AUTHOR => 'Colin Hogben <perl@pythontech.co.uk>',
	      PREREQ_PM => {
		Test::More => 0.32,
	      },
	      );
