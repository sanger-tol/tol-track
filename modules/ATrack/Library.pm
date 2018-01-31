package ATrack::Library;

=head1 NAME

ATrack::Library - Assembly Tracking Library object

=head1 SYNOPSIS
    my $lib = ATrack::Library->new($atrack, $library_id);

    # get arrayref of Seq objects in a library
    my $libs = $library->seqs();

    my $id = $library->id();
    my $name = $library->name();

=head1 DESCRIPTION

An object describing the tracked properties of a library.

Code, a direct descendent of VRTrack::Library from Jim Stalker and Vertebrate
Resequencing.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);
use ATrack::Seq;
use ATrack::Library_type;

use base qw(ATrack::Core_obj
            ATrack::Hierarchy_obj
            ATrack::Named_obj
            ATrack::LIMS_obj);


=head2 fields_dispatch

  Arg [1]    : none
  Example    : my $fieldsref = $lib->fields_dispatch();
  Description: Returns hashref dispatch table keyed on database field
               Used internally for new and update methods
  Returntype : hashref

=cut

sub fields_dispatch
{
    my $self = shift;

    my %fields = %{$self->SUPER::fields_dispatch()};
    %fields = (
        %fields,
        library_id        => sub { $self->id(@_)},
        lims_id           => sub { $self->lims_id(@_)},
        library_type_id   => sub { $self->library_type_id(@_)},
        name              => sub { $self->name(@_)}
    );

    return \%fields;
}

###############################################################################
# Class methods
###############################################################################

=head2 new_by_name

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : library name
  Example    : my $library = ATrack::Library->new_by_name($atrack, $name)
  Description: Class method. Returns current Library object by name.  If no
               such name is in the database, returns undef.  Dies if multiple
               names match.
  Returntype : ATrack::Library object

=cut


=head2 new_by_lims_id

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : library LIMS ID
  Example    : my $library = ATrack::Library->new_by_lims_id($atrack, $lims_id);
  Description: Class method. Returns current Library object by lims_id.  If no
               such lims_id is in the database, returns undef
  Returntype : ATrack::Library object

=cut


=head2 is_name_in_database

  Arg [1]    : library name
  Arg [2]    : hierarchy name
  Example    : if(ATrack::Library->is_name_in_database($atrack, $name, $hname)
  Description: Class method. Checks to see if a name or hierarchy name is
               already used in the library table.
  Returntype : boolean

=cut


=head2 create

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : name
  Example    : my $file = ATrack::Library->create($atrack, $name)
  Description: Class method.  Creates new Library object in the database.
  Returntype : ATrack::Library object

=cut


###############################################################################
# Object methods
###############################################################################

=head2 id

  Arg [1]    : id (optional)
  Example    : my $id = $lib->id();
               $lib->id(104);
  Description: Get/Set for internal db ID of a library
  Returntype : integer

=cut

=head2 lims_id

  Arg [1]    : lims_id (optional)
  Example    : my $lims_id = $lib->lims_id();
               $lib->lims_id('104');
  Description: Get/Set for SequenceScape ID of a library
  Returntype : integer

=cut


=head2 name

  Arg [1]    : name (optional)
  Example    : my $name = $lib->name();
               $lib->name('104');
  Description: Get/Set for library name
  Returntype : string

=cut

=head2 library_type_id

  Arg [1]    : library_type_id (optional)
  Example    : my $library_type_id = $lib->library_type_id();
               $lib->library_type_id(1);
  Description: Get/Set for library library_type_id
  Return_type_id : string

=cut

sub library_type_id
{
    my $self = shift;
    return $self->_get_set('library_type_id', 'number', @_);
}


=head2 library_type

  Arg [1]    : library_type name (optional)
  Example    : my $library_type = $library->library_type();
               $library->library_type('DSS');
  Description: Get/Set for sample library_type. Lazy-loads library_type object
               from $self->library_type_id. If a library_type name is supplied,
               then library_type_id is set to the corresponding library_type in
               the database.  If no such library_type exists, returns undef.
               Use add_library_type to add a library_type in this case.
  Returntype : ATrack::Library_type object

=cut

sub library_type
{
    my $self = shift;
    return $self->_get_set_child_object('get_library_type_by_name', 'ATrack::Library_type', @_);
}


=head2 add_library_type

  Arg [1]    : library_type name
  Example    : my $library_type = $library->add_library_type('DSS');
  Description: create a new library_type, and if successful, return the object
  Returntype : ATrack::Library_type object

=cut

sub add_library_type
{
    my $self = shift;
    return $self->_create_child_object('get_library_type_by_name', 'ATrack::Library_type', @_);
}


=head2 get_library_type_by_name

  Arg [1]    : library_type_name
  Example    : my $library_type = $samp->get_library_type_by_name('DSS');
  Description: Retrieve a ATrack::Library_type object by name
               Note that the library_type object retrieved is not necessarily
               attached to this Library.  Use $lib->library_type for that.
  Returntype : ATrack::Seq_centre object
  Returntype : ATrack::Library_type object

=cut

sub get_library_type_by_name
{
    my ($self,$name) = @_;
    return ATrack::Library_type->new_by_name($self->{atrack}, $name);
}

=head2 seq_centre_id

  Arg [1]    : seq_centre_id (optional)
  Example    : my $seq_centre_id = $lib->seq_centre_id();
               $lib->seq_centre_id(1);
  Description: Get/Set for library sequencing seq_centre_id
  Returntype : string

=cut

sub centre_id
{
    my $self = shift;
    return $self->_get_set('centre_id', 'number', @_);
}

=head2 changed

  Arg [1]    : timestamp (optional)
  Example    : my $changed = $lib->changed();
               $lib->changed('20080810123000');
  Description: Get/Set for library changed
  Returntype : string

=cut


=head2 seqs

  Arg [1]    : None
  Example    : my $seqs = $library->seqs();
  Description: Returns a ref to an array of the Seq objects that are associated
               with this library.
  Returntype : ref to array of ATrack::Seq objects

=cut

sub seqs
{
    my $self = shift;
    return $self->_get_child_objects('ATrack::Seq');
}


=head2 seq_ids

  Arg [1]    : None
  Example    : my $seq_ids = $library->seq_ids();
  Description: Returns a ref to an array of the Seq IDs that are associated
               with this library
  Returntype : ref to array of integer Seq IDs

=cut

sub seq_ids
{
    my $self = shift;
    return $self->_get_child_ids('ATrack::Seq');
}


=head2 add_seq

  Arg [1]    : seq name
  Example    : my $new_seq = $lib->add_seq('2631_3');
  Description: create a new Seq, and if successful, return the object
  Returntype : ATrack::Seq object

=cut

sub add_seq
{
    my $self = shift;
    return $self->_add_child_object('new_by_name', 'ATrack::Seq', @_);
}


=head2 get_seq_by_id

  Arg [1]    : internal seq id
  Example    : my $seq = $lib->get_seq_by_id(47);
  Description: retrieve Seq object by internal db Seq ID
  Returntype : ATrack::Seq object

=cut

sub get_seq_by_id
{
    my $self = shift;
    return $self->_get_child_by_field_value('seqs', 'id', @_);
}


=head2 get_seq_by_name

  Arg [1]    : seq name
  Example    : my $seq = $track->get_seq_by_name('My seq');
  Description: retrieve Seq object attached to this Library, by name
  Returntype : ATrack::Seq object

=cut

sub get_seq_by_name
{
    my $self = shift;
    return $self->_get_child_by_field_value('seqs', 'name', @_);
}


=head2 descendants

  Arg [1]    : none
  Example    : my $desc_objs = $obj->descendants();
  Description: Returns a ref to an array of all objects that are descendants
               of this object
  Returntype : arrayref of objects

=cut

sub _get_child_methods
{
    return qw(seqs);
}

1;
