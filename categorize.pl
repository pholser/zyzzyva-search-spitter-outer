#!/usr/bin/env perl -w

use strict;
use List::Util qw(sum);
use File::Path qw(make_path);

my %point_values = ( A => 1, B => 3, C => 3, D => 2, E => 1, F => 4, G => 2, H => 4, I => 1, J => 8, K => 5, L => 1,
    M => 3, N => 1, O => 1, P => 3, Q => 10, R => 1, S => 1, T => 1, U => 1, V => 4, W => 4, X => 8, Y => 4, Z => 10);

my $categorized = {};

my $length_of_word = sub { length($_) };

my $num_vowels = sub { tr/AEIOU/AEIOU/ };

my $vowel_signature = sub { join('', sort grep(/[AEIOU]/, split(//, $_))); };

my $point_value = sub { sum(map { $point_values{$_} } split(//, $_)); };

my @filters = (
    { short_name => 'length', type => 'Length', filter => $length_of_word, min => '_', max => '_' },
    { short_name => 'vowels', type => 'Number of Vowels', filter => $num_vowels, min => '_', max => '_' },
    { short_name => 'vowelsig', type => 'Includes Letters', filter => $vowel_signature, string => '_', negated => '0' },
    { short_name => 'points', type => 'Point Value', filter => $point_value, min => '_', max => '_' }
);

my $prelude = <<END_PRELUDE;
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE zyzzyva-search SYSTEM 'http://pietdepsi.com/dtd/zyzzyva-search.dtd'>
<zyzzyva-search version="1" >
  <conditions>
    <and>
END_PRELUDE

my $postlude = <<END_POSTLUDE;
    </and>
  </conditions>
</zyzzyva-search>
END_POSTLUDE

while (<>) {
   chomp;
   next if length > 9;
   my $key;
   my $bin = $categorized;

   for (my $index = 0; $index < scalar(@filters) - 1; ++$index, $bin->{$key}->{count}++, $bin = $bin->{$key}) {
       $key = $filters[$index]->{filter}->($_) || 0;
   }

   $key = $filters[-1]->{filter}->($_) || 0;
   $bin->{$key}->{count}++;
   $categorized->{count}++;
}

emit_search($categorized, []);

sub emit_search {
    my($bin, $keys) = @_;
    if ($bin->{count} < 100 or scalar @$keys == scalar @filters) {
        write_search_file($keys);
    } else {
        foreach my $key (keys %$bin) {
            if ($key ne 'count') {
                emit_search($bin->{$key}, [@$keys, $key]);
            }
        }
    }
}

sub write_search_file {
    my($keys) = @_;
    my $file_path = file_path_for_keys($keys);
    my $path = $file_path->{path};
    make_path($path);
    open my $search_file, "> " . $path . '/' . $file_path->{file} or die $!;
    print $search_file $prelude;
    write_conditions($search_file, $keys);
    print $search_file $postlude;
    close $search_file;
}

sub file_path_for_keys {
    my($keys) = @_;
    my @names = map { $keys->[$_] . $filters[$_]->{short_name} } 0 .. $#{$keys};
    my $full_path = join('/', @names) . '.zzs';
    print "dirs = @names[0 .. $#names - 1], file = $names[-1].zzs\n";
    return { path => join('/', @names[0 .. $#names - 1]), file => $names[-1] . '.zzs' };
}

sub write_conditions {
    my($search_file, $keys) = @_;

    for (my $i = 0; $i < @$keys; ++$i) {
        write_condition($search_file, $filters[$i], $keys->[$i]);
    }
}

sub write_condition {
    my($search_file, $filter, $key) = @_;

    print $search_file '<condition ';
    foreach my $attr (keys %$filter) {
        if ($attr ne 'short_name' and $attr ne 'filter') {
            my $value = $filter->{$attr} eq '_' ? $key : $filter->{$attr};
            print $search_file $attr . '="' . $value . '" ';
        }
    }
    print $search_file "/>\n";
}
