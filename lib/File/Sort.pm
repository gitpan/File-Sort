package File::Sort;
use vars qw(@ISA @EXPORT_OK @EXPORT $VERSION *sort1 *sort2 %fh);
use strict;
no strict 'refs';
use Exporter;
use IO::File;
use File::Basename;
use Carp;
@ISA = qw(Exporter);
@EXPORT = ();
@EXPORT_OK = qw(sort_file sortFile);
$VERSION = '0.18';

sub sortFile {
	die "Change sortFile to sort_file, please.  Thanks and sorry.  :)\n";
}

sub sort_file {
	local $\;
	my(
		$count1, $count2, @lines, $lines, $line, @fh, $first, $opts,
		$filein, $uniq, $basedir, $basename, %sort1, %sort2,
	);
	($a, $b, $count1, $count2) = (1, 1, 0, 0);

	if (!$_[0] && (!ref($_[0]) || !$_[1])) {
		croak 'Usage: sort_file($filein, $fileout [, $verbose, $chunk])';
	} elsif (!ref($_[0])) {
		($filein, $$opts{O}, $$opts{V}, $$opts{Y}) = @_;
		$$opts{I} = [$filein];
	} else {
		$opts = \%{$_[0]};
		$$opts{I} = [(ref($$opts{I}) ? @{$$opts{I}} : $$opts{I})];
		croak 'Usage: sort_file({I=>FILEIN, O=>FILEOUT, %otheroptions})'
			if (!$$opts{O} || !@{$$opts{I}});
	}

	$$opts{Y}	||= 20000;
	$$opts{TF}	||= 40;
	$$opts{R}	= $$opts{R} ? 1 : 0;
	$$opts{N}	= $$opts{N} ? 1 : 0;

	{
		my($cmp, $aa, $bb, $fa, $fb) = ('cmp', '$a', '$b', '$fh{$a}', '$fh{$b}');

		if ($$opts{D}) {
			$$opts{D} = quotemeta($$opts{D});
			$$opts{F} ||= 0;
			($aa, $bb, $fa, $fb) = map "(split(/$$opts{D}/, $_))[$$opts{F}]",
				($aa, $bb, $fa, $fb);
		} elsif ($$opts{S}) {
			($aa = $$opts{S}) =~ s/\$SORT/\$a/g;
			($bb = $$opts{S}) =~ s/\$SORT/\$b/g;
			($fa = $$opts{S}) =~ s/\$SORT/\$fh{\$a}/g;
			($fb = $$opts{S}) =~ s/\$SORT/\$fh{\$b}/g;
		}

		($bb, $aa, $fb, $fa) = ($aa, $bb, $fa, $fb)	if ($$opts{R} == 1);
		$cmp = '<=>' if ($$opts{N} == 1);

		local($^W) = 0;
		*sort1 = eval("sub {$aa $cmp $bb}");
		croak if $@;
		*sort2 = eval("sub {$fa $cmp $fb}");
		croak if $@;
	}

	if (!$$opts{M}) {
		foreach $filein (@{$$opts{I}}) {
			($basename, $basedir) = fileparse($filein);
			print "Sorting file $filein ...\n" if $$opts{V};
			open(F, "< $filein\0") or croak($!);
			print "Creating temp files ...\n" if $$opts{V};
			while (defined($line=<F>)) {
				push(@lines, $line);
				$count1++;
				if ($count1 >= $$opts{Y}) {
					push(@fh, _writeTemp($basename, $count2, \@lines, $opts));
					($count1, $count2, @lines) = (0, ++$count2);
					if ($count2 >= $$opts{TF}) {
						@fh = (_mergeFiles($opts, \@fh, _getTemp()));
						$count2 = 0;
						print "\nCreating temp files ...\n" if $$opts{V};
					}
				}
			}
			if (@lines) {
				my $fh = _writeTemp($basename, $count2, \@lines, $opts);
				push(@fh, $fh);
				($count1, $count2, @lines) = (0, ++$count2);
			}
			close(F);
		}
	} else {
		foreach $filein (@{$$opts{I}}) {
			open($filein, "< $filein\0") or croak($!);
			push(@fh, $filein);
		}
	}

	close(_mergeFiles($opts, \@fh, $$opts{O}));
	print "\nDone!\n\n" if $$opts{V};
}

sub _mergeFiles {
	my($opts, $fh, $file) = @_;
	my($uniq, $first, $line, $o, %oth);

	%oth = map {($o++ => $_)} @$fh;
	%fh  = map {
		my $fh = $oth{$_};
		($_ => scalar <$fh>);
	} keys %oth;

	print "\nCreating sorted $file ...\n" if $$opts{V};
	unless (ref($file)) {
		open($file, "+> $file\0") || croak("Can't open $file: $!");
	}

	while (keys %fh) {
		($first) = (sort sort2 keys %fh);
		if ($$opts{U} && $uniq && $uniq ne $fh{$first}) {
			print $file $fh{$first};
			print $fh{$first};
			$uniq = $fh{$first};
		} else {
			print $file $fh{$first};
		}
		my $fh = $oth{$first};
		defined($line=<$fh>) ? $fh{$first} = $line : delete $fh{$first};
	}

	seek($file,0,0);
	return $file;
}

sub _writeTemp {
	my($basename, $count2, $lines, $opts) = @_;
	my $temp = _getTemp() or warn $!;
	$$lines[-1] .= "\n" if ($$lines[-1] !~ m|\n$|);
	print "  $temp\n" if $$opts{V};
	print $temp sort sort1 @{$lines};
	seek($temp,0,0);
	return $temp;
}

sub _getTemp {IO::File->new_tmpfile}

__END__

=head1 NAME

File::Sort - Sort a file or merge sort multiple files

=head1 SYNOPSIS

  use File::Sort qw(sort_file);
  sort_file({
    I=>[qw(file1_new file2_new)],
    O=>'filex_new',
    V=>1, Y=>1000, TF=>50, M=>1, U=>1, R=>1, N=>1,
  });

  sort_file('file1','file1_new',1,1000);


=head1 DESCRIPTION

WARNING: This is probably going to be MUCH SLOWER than using sort(1)
that comes with most Unix boxes.  This was developed primarily because
some perls (specifically, MacPerl) do not have access to potentially
infinite amounts of memory (thus they cannot necessarily slurp in a text
file of several megabytes), nor does everyone have access to sort(1).

Here are some benchmarks that might be of interest (PowerBook G3/292 with
160MB RAM, VM on, and 100MB allocated to the MacPerl app).  The file
was a mail file around 6MB.  Note that once was with a CHUNK value of
200,000 lines; Unix systems can get away with something like that because
of VM, while Mac OS systems cannot, unless you bump up the memory
allocation as done below.  So inevitably you will get much better
performance with large files on Unix than you will on Mac OS.  C'est la
vie.

Note that tests 2 and 3 cannot be performed on the given dataset when
MacPerl has a small amount of memory allocated (like 8MB).  But when
MacPerl has 8MB allocated, the results for tests 1 and 4 are about the
same as when MacPerl has 100MB allocated, showing that the module is
doing its job properly.  :)

NOTE: `sort` calls the MPW sort tool here, which has a slightly
different default sort order than C<sort_file> does.

  #!perl -w
  use File::Sort qw(sort_file);
  use Benchmark;
  timethese(10,{
    1=>q+`sort -o $ARGV[0].1 $ARGV[0]`+,
    2=>q+open(F,$ARGV[0]);open(F1,">$ARGV[0].4");@f=<F>;print F1 sort @f+,
    3=>q+sort_file({I=>$ARGV[0],O=>"$ARGV[0].2",Y=>200000})+,
    4=>q+sort_file({I=>$ARGV[0],O=>"$ARGV[0].3"})+,
  })

  Benchmark: timing 10 iterations of 1, 2, 3, 4...
         1: 185 secs (185.65 usr  0.00 sys = 185.65 cpu)
         2: 152 secs (152.43 usr  0.00 sys = 152.43 cpu)
         3: 195 secs (195.77 usr  0.00 sys = 195.77 cpu)
         4: 274 secs (274.58 usr  0.00 sys = 274.58 cpu)

That all having been noted, there are plans to have this module use sort(1)
if it is available.  Still.


WARNING Part Deux: This module is subject to change in every way, including
in the fact that it exists.  But it seems much less subject to change now
than it did at first.

There are two primary syntaxes:

  sort_file(FILEIN, FILEOUT [, VERBOSE, CHUNK]);

This will sort FILEIN to FILEOUT.  The FILEOUT can be the same as the
FILEIN, but it is required.  VERBOSE is off by default.  CHUNK is how many
lines to deal with at a time (as opposed to how much memory to deal with at a
time, like sort(1); this might change).  The default for Y is 20,000; increase
for better performance, decrease if you run out of memory.

  sort_file({
    I=>FILEIN, O=>FILEOUT, V=>VERBOSE, 
    Y=>CHUNK, TF=>FILE_LIMIT, 
    M=>MERGE_ONLY, U=>UNIQUE_ONLY, 
    R=>REVERSE, N=>NUMERIC,
    D=>DELIMITER, F=>FIELD,
    S=>SORT_THING,
  });

This time, FILEIN can be a filename or an reference to an array of filenames. 
If MERGE_ONLY is true, then C<File::Sort> will assume the files on input are
already sorted.  UNIQUE_ONLY, if true, only outputs unique lines, removing
all others.

FILE_LIMIT is the system's limit to how many files can be opened at once. 
A default value of 40 is given in the module.  The standard port of
perl5.004_02 for Win32 has a limit of 50 open files, so 40 is safe.  To
improve performance increase the number, and if you are getting failures,
try decreasing it.  If you get a warning in C<_writeTemp>, from the call
to C<_getTemp>, you've probably hit your limit.

If given a DELIMITER (which will be passed through C<quotemeta>), then each
line will be sorted on the nth FIELD (default FIELD is 0).  If sorting by
field, it is best if the last field in the line, if used for sorting, has
DELIMITER at the end of the field (i.e., the field ends in DELIMITER, not
newline).

SORT_THING is so you can pass in any arbitrary sort thing you want, where
$SORT is the token representing your $a and $b.  For instance, these are
equivalent:

  # {$a cmp $b}
  sort_file({I=>'b', O=>'b.out'});
  sort_file({I=>'b', O=>'b.out', S=>'$SORT'});

  # {(split(/\|/, $a))[1] cmp (split(/\|/, $b))[1]}
  sort_file({I=>'b', O=>'b.out', D=>'|', IDX=>1});
  sort_file({I=>'b', O=>'b.out', S=>'(split(/\\|/, $SORT))[1]'});

SORT_THING will still need R and N for reverse and numeric sorts.

Note that if FILEIN does not have a linebreak terminating the last line,
a native newline character will be added to it.


=head1 EXPORT

Exports C<sort_file> on request.  C<sortFile> is no longer the function
name.


=head1 BUGS

None!  :)  I plan on making CHUNK and FILE_LIMIT more intelligent somehow.
I did make the default for CHUNK larger, though.

Also, I will have the module use sort(1) if it is available.


=head1 THANKS

Mike Blazer E<lt>blazer@mail.nevalink.ruE<gt>,
Vicki Brown E<lt>vlb@cfcl.comE<gt>,
Gene Hsu E<lt>gene@moreinfo.comE<gt>,
Andrew M. Langmead E<lt>aml@world.std.comE<gt>,
Brian L. Matthews E<lt>blm@halcyon.comE<gt>,
Rich Morin E<lt>rdm@cfcl.comE<gt>,
Matthias Neeracher E<lt>neeri@iis.ee.ethz.chE<gt>,
Miko O'Sullivan E<lt>miko@idocs.comE<gt>,
Tom Phoneix E<lt>rootbeer@teleport.comE<gt>,
Gurusamy Sarathy E<lt>gsar@activestate.comE<gt>.

=head1 AUTHOR

Chris Nandor E<lt>pudge@pobox.comE<gt>
http://pudge.net/

Copyright (c) 1998 Chris Nandor.  All rights reserved.  This program is free
software; you can redistribute it and/or modify it under the same terms as
Perl itself.

=head1 HISTORY

=over 4

=item v0.18 (31 January 1998)

Tests 3 and 4 failed because we hit the open file limit in the
standard Windows port of perl5.004_02 (50).  Adjusted the default
for total number of temp files from 50 to 40 (leave room for other open
files), changed docs.  (Mike Blazer, Gurusamy Sarathy)

=item v0.17 (30 December 1998)

Fixed bug in C<_mergeFiles> that tried to C<open> a passed
C<IO::File> object.

Fixed up docs and did some more tests and benchmarks.

=item v0.16 (24 December 1998)

One year between releases was too long.  I made changes Miko O'Sullivan
wanted, and I didn't even know I had made them.

Also now use C<IO::File> to create temp files, so the TMPDIR option is
no longer supported.  Hopefully made the whole thing more robust and
faster, while supporting more options for sorting, including delimited
sorts, and arbitrary sorts.

Made CHUNK default a lot larger, which improves performance.  On
low-memory systems, or where (e.g.) the MacPerl binary is not allocated
much RAM, it might need to be lowered.


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

Version 0.18 (31 January 1998)

=head1 SEE ALSO

sort(1).

=cut
