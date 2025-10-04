package Perl::Critic::Policy::ControlStructures::ProhibitGotoIntoBlock;

use strict;
use warnings;

use Perl::Critic::Utils qw{ :booleans :characters :severities :ppi };
use base 'Perl::Critic::Policy';
use Readonly;

our $VERSION = '0.000_003';

Readonly::Scalar my $DESC => 'Do not enter a block via a goto';
Readonly::Scalar my $EXPL => 'Entering a block via a goto is unsupported, and will become a fatal error in Perl v5.44.';

Readonly::Scalar my $GOTO => 'goto';

#-----------------------------------------------------------------------------

sub supported_parameters { return }
sub default_severity { return $SEVERITY_HIGH }
sub default_themes { return qw{ bugs trw } }
sub applies_to { return 'PPI::Statement::Break' }

#-----------------------------------------------------------------------------

sub prepare_to_scan_document {
    my ( $self, $doc ) = @_;

    delete $self->{_label};

    foreach my $label ( @{ $doc->find( 'PPI::Token::Label' ) || [] } ) {
        my $block = _find_containing_block( $label )
            or next;
        push @{ $self->{_label}{ $label->content() } }, $block;
    }

    return $self->{_label} ? $TRUE : $FALSE;
}

#-----------------------------------------------------------------------------

sub violates {
    my ( $self, $elem ) = @_;

    my ( $goto, $target ) = $elem->schildren();

    # Unless it's a goto, ignore it.
    $goto
        and $goto->isa( 'PPI::Token::Word' )
        and $goto->content() eq $GOTO
        or return;

    # Unless the target is a word, ignore it.
    $target
        and $target->isa( 'PPI::Token::Word' )
        or return;

    # Stringify the target, and append a colon since the
    # PPI::Token::Label includes it.
    # NOTE that its semantics change below here.
    $target = $target->content() . $COLON;

    foreach my $lbl_blk ( @{ $self->{_label}{$target} || [] } ) {
        foreach my $goto_blk ( _find_all_containing_blocks( $elem ) ) {
            $goto_blk == $lbl_blk
                and return;
        }
    }

    # FIXME I have found two cases where Perl v5.42 does not warn here.
    # They are:
    #
    # if ( ... ) { ... FOO: ... } elsif ( ... ) { ... goto FOO; } ...
    #    This was found in the wild in Image-ExifTool. However, I am
    #    unable to reproduce this. Investigation shows that the relevant
    #    code is in fact tickled in at least one case
    #    (lib/Image/ExifTool/Geotag.pm:), but that module does not
    #    enable warnings. So this is a true positive.
    #
    # my $x; goto FOO; $x = do { say 'Boo!'; FOO: 1 } + 2;
    #    That is, you can `goto ...` a block that forms the left-hand
    #    side of a binary operator. This is actually documented as being
    #    legal in `perldoc -f goto` for Perl v5.42. It is illegal (and I
    #    think throws a fatal exception) if it's the right-hand side. No
    #    idea about chained operators, and my personal opinion that
    #    anyone who uses this construct should be chained to the
    #    computer and forced to maintain this code as long as he or she
    #    lives ... and after, if that can be arranged.
    #
    # OTOH the following cases which parse as a PPI::Structure::Block DO
    # warn:
    #   {; ... } -- a bare block
    #   do { ... } -- though this is NOT a block for (e.g.) `last` etc
    #   while ( ... ) { ... }
    #   sub { ... } -- though this was a different error
    #   for ( ... ) { ... }
    #   given ( ... ) { ... }

    return $self->violation( $DESC, $EXPL, $elem);
}

#-----------------------------------------------------------------------------

sub _find_all_containing_blocks {
    my ( $elem ) = @_;
    my @all;
    my $block = $elem;
    while ( $block = $block->parent() ) {
        $block->isa( 'PPI::Structure::Block' )
            and push @all, $block;
    }
    push @all, $elem->top();
    return @all;
}

#-----------------------------------------------------------------------------

sub _find_containing_block {
    my ( $elem ) = @_;
    my $block = $elem;
    while ( $block = $block->parent() ) {
        $block->isa( 'PPI::Structure::Block' )
            and return $block;
    }
    return $elem->top();
}

#-----------------------------------------------------------------------------

1;

__END__

=for stopwords goto

=head1 NAME

Perl::Critic::Policy::ControlStructures::ProhibitGotoIntoBlock - Do not enter a block via a goto.

=head1 DESCRIPTION

Entering a block via a C<goto> is unsupported, and will become fatal in
Perl v5.44. Before that, the behavior is deprecated as of Perl v5.37.10,
and will issue a warning as of that version. The problem is that if you
enter a block via a C<goto>, any initialization of that block will not
occur.

B<Note> that C<perldoc -f goto> says that C<goto> may be used to jump
into the B<first> parameter of a binary operator. This policy will
generate a false positive for such code. Frankly, just the thought of
such code makes my skin crawl. I am reluctant to spend time to
support it, and would rather use my time and effort advocating the
replacement of such code with something more comprehensible.

=head1 AFFILIATION

This policy is not part of any package.

=head1 CONFIGURATION

This policy is not configurable except for the standard options.

=head1 ACKNOWLEDGMENT

This policy leans heavily on
L<Perl::Critic::Policy::Community::WhileDiamondDefaultAssignment|Perl::Critic::Policy::Community::WhileDiamondDefaultAssignment>
by Dan Book, C<dbook@cpan.org>

=head1 SUPPORT

Support is by the current author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=Perl-Critic-Policy-ControlStructures-ProhibitGotoIntoBlock>,
L<https://github.com/trwyant/perl-Perl-Critic-Policy-ControlStructures-ProhibitGotoIntoBlock/issues>, or in
electronic mail to F<wyant at cpan dot org>.

=head1 AUTHOR

Dan Book, C<dbook@cpan.org>

Thomas R. Wyant, III (F<wyant at cpan dot org>)

=head1 COPYRIGHT

Copyright 2025, Thomas R. Wyant, III

=head1 LICENSE

This library is free software; you may redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<Perl::Critic|Perl::Critic>

L<Perl::Critic::Policy::Community::WhileDiamondDefaultAssignment|Perl::Critic::Policy::Community::WhileDiamondDefaultAssignment>

=cut

# Local Variables:
#   mode: cperl
#   cperl-indent-level: 4
#   fill-column: 72
#   indent-tabs-mode: nil
#   c-indentation-style: bsd
# End:
# ex: set ts=8 sts=4 sw=4 tw=72 ft=perl expandtab shiftround :
