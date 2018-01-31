package ATrack::Centre;

=head1 NAME

ATrack::Centre - Assembly Tracking Centre object

=head1 SYNOPSIS
    my $centre = ATrack::Centre->new($atrack, $centre_id);

    my $id      = $centre->id();
    my $name    = $centre->name();

=head1 DESCRIPTION

An object describing a sequencing_centre, such as SC or BROAD. Centres are
usually attached to a ATrack::Run by the centre_id on the run.

Code, a direct descendent of VRTrack::Seq_centre from Jim Stalker and Vertebrate
Resequencing.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);

use base qw(ATrack::Named_obj);


###############################################################################
# Class methods
###############################################################################

=head2 new

  Arg [1]    : database handle to assembly tracking database
  Arg [2]    : centre id
  Example    : my $centre = ATrack::Centre->new($atrack, $id)
  Description: Returns Centre object by centre_id
  Returntype : ATrack::Centre object

=cut

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}


=head2 fields_dispatch

  Arg [1]    : none
  Example    : my $fieldsref = $file->fields_dispatch();
  Description: Returns hashref dispatch table keyed on database field
               Used internally for new and update methods
  Returntype : hashref

=cut

sub fields_dispatch
{
    my $self = shift;
    return
    {
        centre_id => sub { $self->id(@_) },
        name      => sub { $self->name(@_) },
        long_name => sub { $self->long_name(@_) }
    };
}


=head2 new_by_name

  Arg [1]    : database handle to assembly tracking database
  Arg [2]    : centre name
  Example    : my $centre = ATrack::Centre->new_by_name($atrack, $name)
  Description: Class method. Returns Centre object by Centre name.  If no such
               name is in the database, returns undef
  Returntype : ATrack::Centre object

=cut


=head2 create

  Arg [1]    : database handle to assembly tracking database
  Arg [2]    : centre name
  Example    : my $centre = ATrack::Centre->create($atrack, $name)
  Description: Class method. Creates new Centre object in the database.
  Returntype : ATrack::Centre object

=cut

sub create
{
    my ($self, $atrack, $name) = @_;
    return $self->SUPER::create($atrack, name => $name);
}


###############################################################################
# Object methods
###############################################################################


=head2 dirty

  Arg [1]    : boolean for dirty status
  Example    : $obj->dirty(1);
  Description: Get/Set for object properties having been altered.
  Returntype : boolean

=cut


=head2 id

  Arg [1]    : id (optional)
  Example    : my $id = $centre->id();
               $centre->id('104');
  Description: Get/Set for database ID of a centre
  Returntype : Internal ID integer

=cut


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $centre->name();
               $centre->name('WSI');
  Description: Get/Set for centre name
  Returntype : string

=cut

=head2 long_name

  Arg [1]    : long_name (optional)
  Example    : my $model = $centre->long_name();
               $centre->long_name('Wellcome Sanger Institute');
  Description: Get/Set for long_name of a centre
  Returntype : Internal ID integer

=cut

sub long_name
{
    my $self = shift;
    return $self->_get_set('long_name', 'string', @_);
}


=head2 update

  Arg [1]    : None
  Example    : $centre->update();
  Description: Update a centre whose properties you have changed. If properties
               haven't changed (i.e. dirty flag is unset) do nothing. Unsets
               the dirty flag on success.
  Returntype : 1 if successful, otherwise undef.

=cut

1;
