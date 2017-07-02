package Dist::Zilla::Plugin::AuthorsFromGit;
# ABSTRACT: Add per-file per-year copyright info to each Perl document

use Git::Wrapper;
use DateTime;
use List::MoreUtils qw(uniq sort_by);

use Moose;
with(
  'Dist::Zilla::Role::FileMunger',
  'Dist::Zilla::Role::FileFinderUser' => {
    default_finders => [ ':InstallModules', ':ExecFiles' ],
  },
);

use namespace::autoclean;

#pod =head1 DESCRIPTION
#pod
#pod This plugin ...
#pod
#pod =cut

sub gitauthorlist {
  my ($file, $git)= @_;

  my @log_lines = $git->RUN('log', '--format=%H %at %aN', '--', $file->name);
  my @outputlines;
  push @outputlines, "";

  if (@log_lines) {

    my $earliest_year=3000;
    my $latest_year=0;
    my %authordata;
    my %authorline;

    # Extract the author data and separate by year
    foreach ( @log_lines ) {

      my @fields=split(/ /,$_,3);
      my $when=DateTime->from_epoch(epoch => $fields[1]);
      my $year=$when->year();
      my $author=$fields[2];

      if ($year < $earliest_year) { $earliest_year=$year; };
      if ($year > $latest_year) { $latest_year=$year; };
      if ( $author ne "unknown" ) { push(@{$authordata{$year}}, $author); };
    };

    # Remove duplicates within a year, sort and transform to string
    foreach my $year (keys %authordata) {

      my @un=uniq(@{$authordata{$year}});
      $authorline{$year}=join(', ',sort_by { $_ } @un);

    };

    # Now deduplicate the years
    push @outputlines, "  Copyright $earliest_year       ".$authorline{$earliest_year};

    for ( my $year=$earliest_year+1; $year<=$latest_year; $year++) {

    if ( (defined $authorline{$year}) && (defined $authorline{$year-1}) ) {

      if ($authorline{$year-1} eq $authorline{$year}) {

        my $lastline=$outputlines[-1];
          $lastline=~ s/([0-9]{4})[\- ][0-9 ]{4}/$1-$year/;
          $outputlines[-1]=$lastline;
        } else {
          push @outputlines, "            $year       ".$authorline{$year};
        };

      } elsif ( defined $authorline{$year} ) {

        push @outputlines, "            $year       ".$authorline{$year};

      };
    };
    push @outputlines, "";
  };

  return @outputlines;
}

sub munge_files {
  my ($self) = @_;
  my $git = Git::Wrapper->new(".");

  $self->munge_file($_, $git) for @{ $self->found_files };
}

sub munge_file {
  my ($self, $file, $git) = @_;

  my @gal=gitauthorlist($file,$git);

  return $self->munge_pod($file, @gal);
}

sub munge_pod {
  my ($self, $file, @gal) = @_;

  my @content = split /\n/, $file->content;

  require List::Util;
  List::Util->VERSION('1.33');

  for (0 .. $#content) {
    next until $content[$_] =~ /^=head1 COPYRIGHT AND LICENSE/;

    $_++; # move past the =head1 line itself
    $_++; # and past the subsequent empty line
    
    # Now we should have a line looking like
    #
    # "This software is copyright ... , see the git log."
    #
    # The string ", see the git log." is used as magic to trigger the plugin.
    # We check this format, replace ", see the git log.",
    # and insert the git information afterwards.
    
    if ($content[$_] =~ /^This software is copyright.*, see the git log\.$/ ) {    
    
      $content[$_] =~ s/, see the git log\.$/; in detail:/;
      splice @content, $_+1, 0, @gal;
    
    };

    my $content = join "\n", @content;
    $content .= "\n" if length $content;
    $file->content($content);
    return;

  }

}

__PACKAGE__->meta->make_immutable;
1;

#pod =head1 SEE ALSO
#pod
#pod L<PkgVersion|Dist::Zilla::Plugin::PodVersion>,
#pod
#pod =cut

__END__

