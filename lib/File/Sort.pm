#!perl -w
package File::Sort;
use vars qw(@ISA @EXPORT_OK @EXPORT $VERSION *sort1 *sort2 %fh);
use strict;
no strict 'refs';
use Exporter;
use File::Basename;
use Carp;
@ISA = qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(sortFile);
$VERSION = sprintf("%d.%02d", q$Revision: 0.11 $ =~ /(\d+)\.(\d+)/);

sub sortFile {
	my(
		$count1, $count2, @lines, $lines, $line, @fh, $first, $opts,
		$filein, $uniq, $basedir, $basename, %sort1, %sort2,
	);
	($a, $b, $count1, $count2) = (1, 1, 0, 0);

	if (!$_[0] && (!ref($_[0]) || !$_[1])) {
		croak 'Usage: sortFile($filein, $fileout [, $verbose, $chunk])';
	} elsif (!ref($_[0])) {
		($filein, $$opts{O}, $$opts{V}, $$opts{Y}) = @_;
		$$opts{I} = [$filein];
	} else {
		$opts = \%{$_[0]};
		$$opts{I} = [(ref($$opts{I}) ? @{$$opts{I}} : $$opts{I})];
		croak 'Usage: sortFile({I=>FILEIN, O=>FILEOUT, %otheroptions})'
			if (!$$opts{O} || !@{$$opts{I}});
	}

	$$opts{Y}	||= 3000;
	$$opts{TF}	||= 50;
	$$opts{R}	= $$opts{R} ? 1 : 0;
	$$opts{N}	= $$opts{N} ? 1 : 0;

	%sort1 = (
		'00'=> sub {'a'},
		'01'=> sub {$a <=> $b},
		'10'=> sub {'r'},
		'11'=> sub {$b <=> $a},
	);
	%sort2 = (
		'00'=> sub {$fh{$a} cmp $fh{$b}},
		'01'=> sub {$fh{$a} <=> $fh{$b}},
		'10'=> sub {$fh{$b} cmp $fh{$a}},
		'11'=> sub {$fh{$b} <=> $fh{$a}},
	);
	{
		local($^W) = 0;
		*sort1 = $sort1{($$opts{R} . $$opts{N})};
		*sort2 = $sort2{($$opts{R} . $$opts{N})};
	}

	if (!$$opts{M}) {
		foreach $filein (@{$$opts{I}}) {
			($basename, $basedir) = fileparse($filein);
			$$opts{T} = _tempDir($opts, $basedir) if ($filein eq ${$$opts{I}}[0]);
			print "Sorting file $filein ...\n" if $$opts{V};
			open(F, "<$filein") || croak($!);
			print "Creating temp files ...\n" if $$opts{V};
			while (defined($line=<F>)) {
				push(@lines, $line);
				$count1++;
				if ($count1 >= $$opts{Y}) {
					push(@fh, _writeTemp($basename, $count2, \@lines, $opts));
					($count1, $count2, @lines) = (0, ++$count2);
					if ($count2 >= $$opts{TF}) {
						@fh = (_mergeFiles($opts, \@fh, _getTemp($basename, 'M', $opts)));
						$count2 = 0;
						print "\nCreating temp files ...\n" if $$opts{V};
					}
				}
			}
			if (@lines) {
				push(@fh, _writeTemp($basename, $count2, \@lines, $opts));
				($count1, $count2, @lines) = (0, ++$count2);
			}
			close(F);
		}
	} else {
		foreach $filein (@{$$opts{I}}) {
			open($filein, "<$filein") || croak($!);
			push(@fh, $filein);
		}
	}

	close(_mergeFiles($opts, \@fh, $$opts{O}));
	print "\nDone!\n\n" if $$opts{V};
}

sub _mergeFiles {
	my($opts, $fh, $file) = @_;
	my($uniq, $first, $line);

	%fh = map {($_ => scalar <$_>)} @$fh;

	print "\nCreating sorted $file ...\n" if $$opts{V};
	open($file, "+>$file") || croak($!);

	while (keys %fh) {
		($first) = (sort sort2 keys %fh);
		if ($$opts{U} && $uniq && $uniq ne $fh{$first}) {
			print $file $fh{$first};
			$uniq = $fh{$first};
		} else {
			print $file $fh{$first};
		}
		defined($line=<$first>) ? $fh{$first} = $line : delete $fh{$first};
	}

	print "\nDeleting temp files ...\n" if ($$opts{V} && !$$opts{M});
	foreach (@$fh) {
		close($_);
		unlink($_) unless ($$opts{M});
		print "  $_\n" if ($$opts{V});
	}
	seek($file,0,0);
	return $file;
}

sub _writeTemp {
	my($basename, $count2, $lines, $opts) = @_;
	my($temp) = _getTemp($basename, $count2, $opts);

	$$lines[-1] .= $/ if ($$lines[-1] !~ m|$/$|);
	print "  $temp\n" if $$opts{V};
	open($temp, "+>$temp") || croak($!);
	if (sort1() eq 'a') {
		print $temp sort @{$lines};
	} elsif (sort1() eq 'r') {
		print $temp reverse sort @{$lines};
	} else {
		print $temp sort sort1 @{$lines};
	}
	seek($temp,0,0);
	return $temp;
}

sub _getTemp {
	my($basename, $count2, $opts) = @_;
	my($temp) = $basename . '_' . time . '_' . $count2;
	while (-e $$opts{T} . $temp || ($^O eq 'MacOS' && length($temp) > 31)) {
		$temp .= $count2;
		while ($^O eq 'MacOS' && length($temp) > 31) {
			chop($temp);
			chop($temp);
		}
	}
	$temp = $$opts{T} . $temp;
	return $temp;
}

sub _tempDir {
	my($opts, $basedir) = @_;
	$$opts{T} ||= $^O eq 'MacOS' ? 'h&hTR%f%~)' : '/tmp'; #make sure it's bad :)
	$$opts{T} = -d $$opts{T} ? $$opts{T} :
		$ENV{TMPDIR} || $ENV{TMP} || $ENV{TEMP} || $basedir;
	if ($^O eq 'MacOS') {
		$$opts{T} .= ':' if ($$opts{T} !~ /:$/);
	} elsif ($^O =~ /^MS(DOS|Win32)/i) {
		$$opts{T} .= '\\' if ($$opts{T} !~ /\\$/);
	} elsif ($^O !~ /^VMS/i) {
		$$opts{T} .= '/' if ($$opts{T} !~ /\/$/);
	}
	return $$opts{T};
}

__END__

=head1 NAME

File::Sort - Sort a file or merge sort multiple files.

=head1 SYNOPSIS

  use File::Sort qw(sortFile);
  sortFile({
    I=>[qw(file1_new file2_new)],
    O=>'filex_new',
    V=>1,Y=>1000,TF=>50,M=>1,U=>1,R=>1,N=>1,T=>'/tmp'
  });

  sortFile('file1','file1_new',1,1000);


=head1 DESCRIPTION

WARNING: This is MUCH SLOWER than using sort(1) that comes with most Unix 
boxes.  This was developed primarily because some perls (specifically, 
MacPerl) do not have access to potentially infinite amounts of memory 
(thus they cannot necessarily slurp in a text file of several megabytes), 
nor does everyone have access to sort(1).

Here are some benchmarks that might be of interest (Power Mac 7100/66 with
MkLinux DR2.1, but results were similar on an Ultra SPARC 1 running Solaris 
2.5.1).  The file was a mail file around 6MB.  Note that once was with a 
CHUNK value of 200,000 lines, which was more than the whole file contained; 
Unix systems can get away with something like that because of VM, while Mac 
OS systems cannot.  So inevitably you will get much better performance with 
large files on Unix than you will on Mac OS.  C'est la vie.

  use File::Sort qw(sortFile);
  use Benchmark;
  timethese(10,{
    1=>q+`sort -o $ARGV[0].1 $ARGV[0]`+,
    2=>q+open(F,$ARGV[0]);open(F1,">$ARGV[0].4");@f=<F>;print F1 sort @f+
    3=>q+sortFile({I=>$ARGV[0],O=>"$ARGV[0].2",Y=>200000})+,
    4=>q+sortFile({I=>$ARGV[0],O=>"$ARGV[0].3"})+,
  })

  Benchmark: timing 10 iterations of 1, 2, 3...
    1: 161 secs ( 0.01 usr  0.03 sys + 105.47 cusr 34.37 csys = 139.88 cpu)
    2: 262 secs (215.18 usr 21.60 sys = 236.78 cpu)
    3: 781 secs (670.78 usr 48.45 sys = 719.23 cpu)
    4: 13239 secs (12981.68 usr 79.65 sys = 13061.33 cpu)

That all having been noted, there are plans to have this module use sort(1)
if it is available.

WARNING Part Deux: This module is subject to change in every way, including
the fact that it exists.

There are two primary syntaxes:

  sortFile(INFILE, OUTFILE [, VERBOSE, CHUNK]);

This will sort INFILE to OUTFILE.  The OUTFILE can be the same as the
INFILE, but it is required.  VERBOSE is off by default.  CHUNK is how many
lines to deal with at a time (as opposed to how much memory to deal with at a
time, like sort(1); this might change).  We hope to gain some more 
intelligence for sort in the future.

  sortFile({
    I=>INFILE, O=>OUTFILE, V=>VERBOSE, 
    Y=>CHUNK, TF=>FILE_LIMIT, 
    M=>MERGE_ONLY, U=>UNIQUE_ONLY, 
    R=>REVERSE, N=>NUMERIC, T=>TEMP_DIR
  });

This time, FILEIN can be a filename or an reference to an array of filenames. 
If MERGE_ONLY is true, then C<File::Sort> will assume the files on input are
already sorted.  UNIQUE_ONLY, if true, only outputs unique lines, removing
all others.  TEMP_DIR gives a location for temporary directory.  A default
will try to be ascertained if it none is given, finally reverting to the
directory of the outfile if none is given.  FILE_LIMIT is the system's limit
to how many files can be opened at once.  A default value is given in the 
module.

Note that if INFILE does not have a linebreak terminating the last line,
a native linebreak character will be added to it.

=head1 EXPORT

Exports C<sortFile()> on request.

=head1 RETURN VALUE

Currently, C<sortFile()> returns nothing.  Any ideas on this are welcome.

=head1 BUGS

None!  :)  I plan on making CHUNK and FILE_LIMIT more intelligent somehow, 
and on allowing more ordering options besides just regular, numeric and reverse.

Also, I will have the module use sort(1) if it is available.

=head1 AUTHOR

Chris Nandor F<E<lt>pudge@pobox.comE<gt>>
http://pudge.net/

Copyright (c) 1998 Chris Nandor.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=head1 HISTORY

=over 4

=item v0.11 (04 January 1998)

More cleanup; fixed special case of no linebreak on last line; wrote test 
suite; fixed warning for redefined subs (sort1 and sort2).

=item v0.10 (03 January 1998)

Some cleanup; made it not subject to system file limitations; separated 
many parts out into separate functions.

=item v0.03 (23 December 1997)

Added reverse and numeric sorting options.

=item v0.02 (19 December 1997)

Added unique and merge-only options.

=item v0.01 (18 December 1997)

First release.

=back

=head1 VERSION

Version 0.11 (03 January 1998)

=head1 SEE ALSO

perl(1), sort(1).

=cut
