#
# Copyright 2008 Paul Driver <frodwith@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

package POE::Component::MessageQueue::Storage::Remote::Server;
use Moose;
use POE;
use POE::Filter::Reference;
use POE::Component::Server::TCP;
use POE::Component::MessageQueue::Storage::BigMemory;

has session_id => (
	is       => 'rw',
	isa      => 'Int',
	init_arg => undef,
);

has storage => (
	is      => 'ro',
	does    => 'POE::Component::MessageQueue::Storage',
	default => sub { POE::Component::MessageQueue::Storage::BigMemory->new },
);

has port => (
	is       => 'ro',
	isa      => 'Int',
	required => 1,
);

sub BUILD
{
	my ($self, $args) = @_;

	$self->session_id(POE::Component::Server::TCP->new(
		Port         => $self->port,
		ClientFilter => POE::Filter::Reference->new("YAML"),

		ClientInput  => sub {
			my ($heap, $request) = @_[HEAP, ARG0];
			my ($method, $args) = @{$request}{'method', 'args'};
			my $callback_id = pop(@$args);
			my $storage = $self->storage;
			if (my $method_ref = $storage->can($method))
			{
				$method_ref->($storage, @$args, sub {
					$heap->{client}->put({
						callback => $callback_id,
						args     => [@_]
					});
					$poe_kernel->post($self->session_id, 'shutdown') 
						if ($method eq 'storage_shutdown');
				});
			}
		},
	));
}

1;
