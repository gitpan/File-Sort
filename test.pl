#!perl -w
use diagnostics;
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..7\n"; }
END {print "not ok 1\n" unless $loaded;}
use lib 'lib', 'blib';
use File::Sort 0.18;
use File::Sort qw(sort_file);
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):


{
	my $fail1 = 0;
	my $fail2 = 0;
	my @files = qw(
		Sort.pm_sorted
		Sort.pm_sorted.txt
		Sort.pm_rsorted
		Sort.pm_rsorted.txt
  	);
	sort_file({I=>'Sort.pm_unsorted.txt', O=>$files[0]});
	sort_file({I=>'Sort.pm_unsorted.txt', O=>$files[2], R=>1});

	open(F0, $files[0])	|| $fail1++;
	open(F1, $files[1])	|| $fail1++;
	open(F2, $files[2])	|| $fail2++;
	open(F3, $files[3])	|| $fail2++;
	while(<F1>) {
		chomp;
		my $l = <F0>;
		($fail1++ && last) if !defined($l);
		chomp($l);
		$fail1++ if ($l ne $_);
	}
	while(<F3>) {
		chomp;
		my $l = <F2>;
		($fail2++ && last) if !defined($l);
		chomp($l);
		$fail2++ if ($l ne $_);
	}
	close(F0);
	close(F1);
	close(F2);
	close(F3);
	printf "%s 2\n", ($fail1 ? 'not ok' : 'ok');
	printf "%s 3\n", ($fail2 ? 'not ok' : 'ok');
	unlink(@files[0,2]) unless ($fail1 || $fail2);
}

{
	srand();
	my $fail1 = 0;
	my $fail2 = 0;
	my @files = qw(
		:test1
		:test2
		:test3
	);
	my @lines;
	for (0 .. 99) {
		(rand() > .5) ? push(@lines, $_) : unshift(@lines, $_);
	}
	open(F0,">$files[0]") || ($fail1++ && $fail2++);
	print F0 join("\n", @lines);
	close(F0);
	sort_file({I=>$files[0], O=>$files[1], N=>1, Y=>2});
	sort_file({I=>$files[0], O=>$files[2], N=>1, R=>1, Y=>2});

	open(F1, $files[1])	|| $fail1++;
	open(F2, $files[2])	|| $fail2++;

	for (0 .. 99) {
		my $l = <F1>;
		($fail1++ && last) if !defined($l);
		chomp($l);
		$fail1++ if ($l != $_);
	}
	for (reverse (0 .. 99)) {
		my $l = <F2>;
		($fail2++ && last) if !defined($l);
		chomp($l);
		$fail2++ if ($l != $_);
	}
	printf "%s 4\n", ($fail1 ? 'not ok' : 'ok');
	printf "%s 5\n", ($fail2 ? 'not ok' : 'ok');
	unlink(@files) unless ($fail1 || $fail2);
}

{
	srand();
	my $fail1 = 0;
	my $fail2 = 0;
	my @files = qw(
		:test1
		:test2
		:test3
	);
	my @lines;
	for (0 .. 99) {
		(rand() > .5) ? push(@lines, sprintf "%s|$_", $_%2)
		    : unshift(@lines, sprintf "%s|$_", $_%2);
	}
	open(F0,">$files[0]") || ($fail1++ && $fail2++);
	print F0 join("\n", @lines);
	close(F0);
	sort_file({I=>$files[0], O=>$files[1], N=>1, D=>'|', F=>1, Y=>3});
	sort_file({I=>$files[0], O=>$files[2], N=>1, R=>1, D=>'|', F=>1, Y=>3});
	
	open(F1, $files[1])	|| $fail1++;
	open(F2, $files[2])	|| $fail2++;

	for (0 .. 99) {
		my $l = <F1>;
		($fail1++ && last) if !defined($l);
		chomp($l);
		$_ = sprintf "%s|$_", $_%2;
		$fail1++ if ($l ne $_);
	}
	for (reverse (0 .. 99)) {
		my $l = <F2>;
		($fail2++ && last) if !defined($l);
		chomp($l);
		$_ = sprintf "%s|$_", $_%2;
		$fail2++ if ($l ne $_);
	}
	printf "%s 6\n", ($fail1 ? 'not ok' : 'ok');
	printf "%s 7\n", ($fail2 ? 'not ok' : 'ok');
	unlink(@files) unless ($fail1 || $fail2);
}

