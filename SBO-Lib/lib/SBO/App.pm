package SBO::App;

# vim: ts=2:et
#
# authors: Luke Williams <xocel@iquidus.org>
#          Jacob Pipkin <j@dawnrazor.net>
#          Andreas Guldstrand <andreas.guldstrand@gmail.com>
# license: WTFPL <http://sam.zoy.org/wtfpl/COPYING>

use 5.16.0;
use strict;
use warnings FATAL => 'all';
use File::Basename;

our $VERSION = '2.6';

sub new {
  my $class = shift;

  my $self = $class->_parse_opts(@_);
  $self->{fname} = basename( (caller(0))[1] );

  return bless $self, $class;
}

1;
