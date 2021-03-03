package ATrack::History;

=head1 NAME

ATrack::History - Assembly Tracking History object

=head1 SYNOPSIS

use ATrack::History;

my $hist = ATrack::History->new();

# create an instance of one of the Core_obj-inheriting classes as normal, eg:
my $lane = ATrack::Lane->new_by_name($atrack, 'foo');

# supply it to one of the methods of this class. Eg. to get the date the lane's
# library was last changed:
my $datetime = $hist->state_change($lane, 'library_id');

# or the date the lane's processed flag was last set to 'swapped'
$datetime = $hist->was_processed($lane, 'swapped');

# Now make all Core_obj-inheriting classes return the most recent versions that
# are older than our datetime (ie. view the database as it was immediately
# prior to the event associated with our datetime):
$hist->time_travel($datetime);

# ... do stuff with new Core_obj instances, which represent the old db state

# Revert back to normal behaviour (current version):
$hist->time_travel('current');

=head1 DESCRIPTION

This module lets you choose a particular point in time based on a desired
state of a particular database entry, then sets the Core_obj api to return
the current version of objects not younger than that time point.

E.g. if at some point a lane swapped libraries, you can effectively return to
the state of the database just before it was swapped, to discover what the
original library was.

=head1 AUTHOR

sb10@sanger.ac.uks

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);
use ATrack::Core_obj;
use DateTime;


=head2 new

  Example    : my $obj = $class->new()
  Description: Make a new ATrack::History object
  Returntype : $class object

=cut

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, ref($class) || $class;
    return $self;
}


=head2 historical_objects

  Arg [1]    : ATrack::Core_obj-inheriting instance
  Example    : my @objs = $class->historical_objects($lane);
  Description: Get a list of instances of all versions of your Core_obj
               throughout history.
  Returntype : list of Core_obj-inheriting instances (one of which will
               correspond to Arg [1], ordered oldest to current)

=cut

sub historical_objects
{
    my ($self, $core_obj) = @_;
    ($core_obj && ref($core_obj) && $core_obj->isa('ATrack::Core_obj')) || confess "A ATrack::Core_obj is required";
    my $atrack = $core_obj->atrack;
    my $id = $core_obj->id;

    my @row_ids = $core_obj->row_ids;
    my @objs;
    foreach my $row_id (@row_ids)
    {
      push(@objs, $core_obj->new($atrack, $id, $row_id));
    }

    return @objs;
}


=head2 state_change

  Arg [1]    : ATrack::Core_obj-inheriting instance
  Arg [2]    : name of a method of Arg[1] - the state to look for being changed
  Example    : my $datetime = $class->state_change($lane, 'library_id');
  Description: Get the datetime corresponding to the last time that a certain
               state changed.
  Returntype : datetime formatted string (or 'current' if the state never
               changed)

=cut

sub state_change
{
    my ($self, $core_obj, $method) = @_;
    confess "A Core_obj and one of its methods must be supplied" unless $core_obj && $method && $core_obj->can($method);

    my @objs = reverse($self->historical_objects($core_obj));
    my $current = shift(@objs);
    my $current_state = $current->$method;
    my $changed = 'current';
    foreach my $obj (@objs)
    {
        my $state = $obj->$method;
        if ("$state" ne "$current_state")
        {
          $changed = $obj->changed;
          last;
        }
    }

    return $changed;
}


=head2 was_processed

  Arg [1]    : ATrack::Core_obj-inheriting instance
  Arg [2]    : name of an allowed processed flag
  Example    : my $datetime = $class->was_processed($lane, 'swapped');
  Description: Get the datetime corresponding to the last time that a certain
               processed flag was set. Arg[1] must have an is_processed()
               method.
  Returntype : datetime formatted string (or 'current' if the flag was never
               set)

=cut

sub was_processed
{
    my ($self, $core_obj, $flag) = @_;
    confess "A Core_obj that supports is_processed() is required" unless $core_obj && $core_obj->can('is_processed');

    # we want the changed time of the oldest row in the most recent uninterupted
    # block of rows that match our processed flag
    my @objs = reverse($self->historical_objects($core_obj));
    my $changed = 'current';
    my $block_started = 0;
    foreach my $obj (@objs)
    {
        my $processed = $obj->is_processed($flag);
        if ($processed)
        {
            $block_started = 1;
            $changed = $obj->changed;
        }
        elsif ($block_started) {
            last;
        }
    }

    return $changed;
}


=head2 time_travel

  Arg [1]    : datetime string|'current'
  Example    : $obj = $class->time_travel('2010-01-04 10:49:10');
  Description: Set all Core_obj inheriting classes to return new instances as if
               we had travelled back in time to immediately prior to the given
               datetime. Revert back to normal behaviour by setting the 'current'
               keyword.
  Returntype : n/a

=cut

sub time_travel
{
    my $self = shift;
    ATrack::Core_obj->global_history_date(@_);
}


=head2 datetime_cmp

  Arg [1]    : datetime string
  Arg [2]    : datetime string
  Example    : $obj = $class->datetime_cmp('2010-01-04 10:49:10', '2010-01-04 11:40:34');
  Description: Compare two mysql datetime strings.
  Returntype : int: -1 if first is earlier than second, 1 if it's later, and 0
               if they are equal.

=cut

sub datetime_cmp
{
    my ($self, $first, $second) = @_;

    my @epochs;
    foreach my $string ($first, $second)
    {
        $string =~ /^(\d+)-(\d+)-(\d+)\s+(\d+):(\d+):(\d+)/;

        my $dt = DateTime->new(year => $1, month => $2, day => $3, hour => $4, minute => $5, second => $6);

        push(@epochs, $dt->epoch);
    }

    return $epochs[0] <=> $epochs[1];
}


=head2 lane_changed

 Title   : lane_changed
 Usage   : if ($obj->lane_changed($lane, '2010-01-04 10:49:10')) { ... }
 Function: Find out if a lane was changed (remapped, swapped, fastq changed,
           improved, changed withdrawn state) or brand new since since the
           supplied date.
 Returns : boolean (true if the lane is new or changed since the date)
 Args    : ATrack::Lane object, mysql datetime formatted string

=cut

sub lane_changed
{
    my ($self, $lane, $datetime) = @_;

    my @versions = $self->historical_objects($lane);
    my $hist_date = $lane->global_history_date();

    my $changed = 0;
    my $was_mapped = 0;
    my $was_withdrawn = 0;
    my $saw_version = 0;
    my $is_mapped = $lane->is_processed('mapped');
    my $is_withdrawn = $lane->is_withdrawn;
    VERSION: foreach my $version (@versions)
    {
        my $changed = $version->changed;
        if ($hist_date ne 'current' && $self->datetime_cmp($hist_date, $changed) == -1)
        {
            last;
        }
        unless ($self->datetime_cmp($datetime, $changed) == -1)
        {
            $was_mapped = $version->is_processed('mapped');
            $was_withdrawn = $version->is_withdrawn;
            next;
        }
        $saw_version = 1;

        if (! $version->is_processed('mapped') && $was_mapped)
        {
            $changed = 1;
            last;
        }
        foreach my $status (qw(deleted swapped altered_fastq improved))
        {
            if ($version->is_processed($status))
            {
                $changed = 1;
                last VERSION;
            }
        }
    }

    unless ($saw_version)
    {
        $was_mapped = $is_mapped;
        $was_withdrawn = $is_withdrawn;
    }

    return ($was_mapped != $is_mapped || $was_withdrawn != $is_withdrawn || $changed) ? 1 : 0;
}

1;
