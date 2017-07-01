package Dist::Zilla::Plugin::AuthorsFromGit;
# ABSTRACT: Add per-file per-year copyright info to each Perl document

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
  return ( "   a", "   b", "   c" );
}

sub munge_files {
  my ($self) = @_;

  $self->munge_file($_) for @{ $self->found_files };
}

sub munge_file {
  my ($self, $file) = @_;

  return $self->munge_pod($file);
}

sub munge_pod {
  my ($self, $file) = @_;

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
    # We check this format, replace ", see the git log." with ".", 
    # and insert the git information afterwards.
    
    if ($content[$_] =~ /^This software is copyright.*, see the git log\.$/ ) {    
    
      $content[$_] =~ s/, see the git log\.$/./;
      splice @content, $_+1, 0, gitauthorlist($file);
    
    } else {
      $self->log([
        "couldn't find ', see the git log.' in %s, not modifying",
        $file->name,
      ]);
      print " line is \'$content[$_]\'\n";
    };

    my $content = join "\n", @content;
    $content .= "\n" if length $content;
    $file->content($content);
    return;

  }

  $self->log([
    "couldn't find '=head1 COPYRIGHT AND LICENSE' in %s, not modifying",
    $file->name,
  ]);
}

__PACKAGE__->meta->make_immutable;
1;

#pod =head1 SEE ALSO
#pod
#pod L<PkgVersion|Dist::Zilla::Plugin::PodVersion>,
#pod
#pod =cut

__END__

