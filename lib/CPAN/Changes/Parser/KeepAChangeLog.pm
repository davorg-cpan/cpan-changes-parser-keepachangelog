package CPAN::Changes::Parser::KeepAChangeLog;

use strict;
use warnings;

use Moo;
extends 'CPAN::Changes::Parser';

has '+version_like' => (
  is      => 'ro',
  default => sub { qr/Unreleased/i },
);

sub parse_string {
    my ($self, $string, @rest) = @_;
    return undef unless defined $string;

    my $transformed = _kac_to_cpan_changes_spec($string);
    return undef unless defined $transformed;

    return $self->SUPER::parse_string($transformed, @rest);
}

# Transform Keep a Changelog 1.1.0-ish Markdown into CPAN::Changes::Spec-ish text.
# Returns transformed string, or undef if it doesn't look like KaC / can't be transformed.
sub _kac_to_cpan_changes_spec {
    my ($in) = @_;

    # Quick “does this plausibly look like Keep a Changelog?” gate.
    # We require at least one release heading of the KaC form.
    return undef unless $in =~ /^\s*##\s+\[(?:Unreleased|[^\]]+)\]/m;

    my @out;
    my $saw_release = 0;

    for my $line (split /\n/, $in, -1) {
        # Drop CR if file is CRLF
        $line =~ s/\r\z//;

        # Drop KaC link reference definitions (commonly at bottom), e.g.:
        #   [1.0.0]: https://example/compare/v0.9.0...v1.0.0
        #   [Unreleased]: https://example/compare/v1.0.0...HEAD
        if ($line =~ /^\s*\[[^\]]+\]:\s+\S+/) {
            next;
        }

        # Release headings:
        #   ## [1.1.0] - 2024-01-31
        #   ## [1.1.0]
        #   ## [Unreleased]
        if ($line =~ /^\s*##\s+\[([^\]]+)\]\s*(?:-\s*([0-9]{4}-[0-9]{2}-[0-9]{2}))?\s*$/) {
            my ($ver, $date) = ($1, $2);

            # Normalise Unreleased to a CPAN::Changes-ish release line with an allowed “date” token.
            if ($ver =~ /\AUnreleased\z/i) {
                push @out, "Unreleased Not Released";
            }
            else {
                # If date is missing, KaC is still KaC, but CPAN::Changes parser expects something date-like.
                # We'll accept missing date and set it to "Unknown" (allowed by CPAN::Changes::Spec).
                $date //= 'Unknown';
                push @out, "$ver $date";
            }

            $saw_release = 1;
            next;
        }

        # Category headings:
        #   ### Added
        #   ### Fixed
        # Map to CPAN group marker:
        #   [Added]
        if ($line =~ /^\s*###\s+(.+?)\s*$/) {
            my $group = $1;

            # Be conservative: ignore empty/odd headings that are likely Markdown scaffolding.
            $group =~ s/\s+\z//;
            $group =~ s/\A\s+//;

            # If it’s something like “Links” or “Changelog” we still *could* treat it as a group,
            # but KaC categories are the main use. We'll accept any text, as CPAN::Changes groups are free-form.
            push @out, "[$group]";
            next;
        }

        # Top-level title:
        #   # Changelog
        # Treat as preamble. CPAN::Changes parser supports preamble, so keep it (as plain text).
        if ($line =~ /^\s*#\s+(.+?)\s*$/) {
            push @out, $1;
            next;
        }

        # Keep bullets but normalise to "- " for consistency.
        # Preserve indentation for nested bullets.
        if ($line =~ /^(\s*)[*-]\s+(.*)$/) {
            push @out, $1 . "- " . $2;
            next;
        }

        # Otherwise: pass through line as-is.
        push @out, $line;
    }

    return undef unless $saw_release;

    # Basic sanity: after transform, we should still have at least one release line
    # that the base parser is likely to recognise. We can't call its private regex here,
    # but we can assert we emitted something release-like.
    my $out = join("\n", @out);
    return undef unless $out =~ /^\s*(?:Unreleased|[0-9A-Za-z_.]+)\s+(?:\d{4}-\d{2}-\d{2}|Unknown|Not Released)\b/m;

    return $out;
}

1;

