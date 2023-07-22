package ATrack::Core_obj;

=head1 NAME

ATrack::Core_obj - Assembly Tracking Core_obj object

=head1 SYNOPSIS

=head1 DESCRIPTION

This is the superclass of the core objects (Project, Specimen, Sample, Library, Seq) in
ATrack, and implements some common methods.

The primary feature of a core object is that it has a history and concept of a
current version.

=head1 AUTHOR

sm15@sanger.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;
use Carp qw(cluck confess);

use base qw(ATrack::Table_obj);


our $HISTORY_DATE = 'current';
our %allowed_status;


=head2 new

  Arg [1]    : atrack handle
  Arg [2]    : obj id
  Arg [3]    : 'current'(default)|datetime string(in the format returned by
               changed())|row_id (optional)|most_recent
  Example    : my $obj= $class->new($atrack, $id)
  Description: Returns core objects by id. By default this will be the current
               version of the object. If Arg[3] is supplied, or if
               global_history_date() has been changed, the version returned will
               be the most recent version of the object that is older than
               the desired date. If Arg[3] is a row_id, the version with that
               row_id will be returned.
  Returntype : $class object

=cut

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    return $self;
}

sub _initialize
{
    my ($self, $id, $date) = @_;

    my $table = $self->_class_to_table;

    my $fields = $self->fields_dispatch;
    my $sql = qq[SELECT row_id,].(join ", ", keys %$fields).qq[ FROM $table WHERE ${table}_id = ?];
    $sql .= $self->_history_sql($date);

    my $sth = $self->{_dbh}->prepare($sql);

    if ($sth->execute($id))
    {
        my $data = $sth->fetchall_arrayref({}); # return array of hashes
        unless (@$data)
        {
            return;
        }
        # use the most recent row
        my $row = $data->[-1];

        foreach (keys %$fields)
        {
            $fields->{$_}->($row->{$_});
        }

        # handle row_id as a special case outside fields_dispatch, as otherwise
        # we'd need to remove it from fields_dispatch before update.
        # Note also it is hard-coded in the select statement above
        $self->row_id($row->{'row_id'});

        $self->dirty(0); # unset the dirty flag
    }
    else
    {
        confess "Cannot retrieve $table: ".$DBI::errstr;
    }
}

sub _history_sql
{
    my ($self, $thing) = @_;

    my $date_stamp = $thing || $self->global_history_date();

    my $sql = '';
    if ("$date_stamp" eq 'current')
    {
        $sql = qq[ AND current = true];
    }
    elsif ($date_stamp =~ /^\d+$/)
    {
        # presume it's a row_id
        $sql = qq[ AND row_id = $date_stamp];
    }
    elsif ($date_stamp =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/)
    {
        # get the most recent row with a 'changed' that is older than
        # the desired date
        $sql = qq[ AND changed < '$date_stamp' ORDER BY changed,row_id ASC];
    }
    elsif ("$date_stamp" eq 'most_recent')
    {
        # get the most recent row. This may have had current unset, which is
        # why you'd use this rather than 'current' (which should really be
        # called 'current').
        $sql = qq[ ORDER BY changed,row_id ASC];
    }
    else
    {
        confess "bad datetime/row_id supplied ('$date_stamp')";
    }

    return $sql;
}


=head2 global_history_date

  Arg [1]    : 'current'(default)|datestamp string(in the format returned by
               changed()) (optional)
  Example    : my $datestamp = $class->global_history_date();
               $class->global_history_date('2010-01-04 10:49:10');
  Description: When called on any instance or class inheriting from Core_obj,
               gets/sets the date used for determining which version of a
               Core_obj is instantiated when any new*() method is subsequently
               used. By default the current version is returned, and the special
               keyword 'current' can be used to manually choose this.
               new*() methods have an optional arg to also pick a date; these
               will temporarily override the date set here.
  Returntype : string

=cut

sub global_history_date
{
    my ($self, $date) = @_;

    if ($date)
    {
        unless ($date =~ /^(current|\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})$/)
        {
            confess "invalid date format set ('$date')";
        }
        $HISTORY_DATE = $date;
    }

    return $HISTORY_DATE;
}


=head2 fields_dispatch

  Arg [1]    : none
  Example    : my $fieldsref = $obj->fields_dispatch();
  Description: Returns hash dispatch table keyed on database field.
               Used internally for new and update methods. Should be extended
               by inheriting classes to add their unique table columns and
               methods. NB: inheriting classes should initialise their hash by
               calling SUPER::fields_dispatch.
  Returntype : hash ref

=cut

sub fields_dispatch
{
    my $self = shift;

    my %fields = (
        note_id => sub { $self->note_id(@_)},
        changed => sub { $self->changed(@_)},
        current => sub { $self->is_current(@_)}
    );

    return \%fields;
}


=head2 new_by_field_value

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : field name
  Arg [3]    : field value
  Arg [4]    : 'current'(default)|datetime string(in the format returned by
               changed())|row_id (optional)
  Example    : my $obj = $class->new_by_field_value($atrack, 'name',$name)
  Description: Class method. Returns current $class object by field name and
               value. If no such value is in the database, returns undef.
               Dies if there is more than one matching record.
               On success, by default the current version of the object will be
               returned. If Arg[4] is supplied, or if global_history_date() has
               been changed, the version returned will be the most recent
               version of the object that is older than the desired date. If
               Arg[4] is a row_id, the version with that row_id will be
               returned.
  Returntype : $class object

=cut

sub new_by_field_value
{
    my $class = shift;
    return $class->SUPER::new_by_field_value(@_);
}

sub _get_id_by_field_value
{
    my ($self, $dbh, $table, $field, $value, $date) = @_;

    my $sql = qq[SELECT ${table}_id FROM $table WHEREw $field = ?];
    $sql .= $self->_history_sql($date);

    my $sth = $dbh->prepare($sql);
    my $id;
    if ($sth->execute($value))
    {
        my $data = $sth->fetchall_arrayref({}); # return array of hashes
        unless (@$data)
        {
            return;
        }
        if (scalar @$data > 1)
        {
            # check all the table ids are the same
            my $all_same = 1;
            my $last_id;
            foreach my $row (@{$data})
            {
                my $this_id = $row->{"${table}_id"};
                $last_id ||= $this_id;
                if ($this_id != $last_id)
                {
                    $all_same = 0;
                    last;
                }
            }
            confess "$field = $value is not a unique identifier for $table\n" unless $all_same;
        }
        $id = $data->[-1]{"${table}_id"};
    }
    else
    {
        confess "Cannot retrieve $table by $field = $value: ".$DBI::errstr;
    }

    return $id;
}


=head2 create

  Arg [1]    : atrack handle to seqtracking database
  Arg [2]    : name
  Example    : my $obj = ATrack::Core_obj->create($atrack, $name)
  Description: Class method.  Creates new object in the database.
  Returntype : ATrack::Core_obj inheriting object

=cut

sub create
{
    my ($class, $atrack, $id) = @_;
    confess "Need to call with a atrack handle" unless $atrack;
    confess "The interface has changed, expected atrack reference." if $atrack->isa('DBI::db');

    my $dbh = $atrack->{_dbh};
    my $table = $class->_class_to_table;

    # Small hack.  This sub assumes that if a 3rd param has been passed
    # then it is a name, but create can be called by
    # Table_obj->_add_child_object, which takes identifiers that are not
    # necessarily names (e.g. lims_id for library_request).  It would be nice
    # for this create to Do The Right Thing for each type of identifier
    # with explicit setting of identifier type, but for now we'll just
    # assume that if we have an identifier and can->name, it's a name, if
    # we can't name but can->lims_id, it's an lims_id, otherwise drop it.  jws
    # 2010-09-30

    my ($name, $lims_id);
    if ($class->can('name'))
    {
        $name = $id;
    }
    elsif ($class->can('lims_id'))
    {
        $lims_id = $id;
    }
    else {
        # id gets ignored
    }

    # prevent adding an object with an existing name, if name supplied. In case
    # of mapstats, the name is void
    if ($name && $class->is_name_in_database($atrack, $name, $name))
    {
        confess "Already a $table entry with value $name";
    }

    my $next_id;
    my $success = $atrack->transaction(sub {
        # insert a fake record to obtain a unique id (row_id)
        my $query = qq[INSERT INTO $table SET ${table}_id=0];
        my $sth   = $dbh->prepare($query) or confess qq[The query "$query" failed: $!];
        my $rv    = $sth->execute or confess qq[The query "$query" failed: $!];

        # now update the inserted record
        $next_id = $dbh->last_insert_id(undef, undef, $table, 'row_id') or confess "No last_insert_id? $!";

        if ($name)
        {
            my $hierarchy_name;

            my $fieldsref = $class->fields_dispatch();
            if ( exists($fieldsref->{hierarchy_name}) )
            {
                $hierarchy_name = $name;
                $hierarchy_name =~ s/\W+/_/g;
            }

            $name = qq[name='$name' ];
            if ($hierarchy_name)
            {
                $name .= qq[, hierarchy_name='$hierarchy_name' ];
            }
        }

        $query = qq[UPDATE $table SET ${table}_id=$next_id];
        if ($name)
        {
            $query .= qq[, $name ];     # add name, hierarchy_name clause
        }
        elsif ($lims_id)
        {
            $query .= qq[, lims_id=$lims_id ]; # add lims_id clause
        }

        $query .= qq[, changed=now(), current=true WHERE row_id=$next_id];
        $sth   = $dbh->prepare($query) or confess qq[The query "$query" failed: $!];
        $sth->execute or confess qq[The query "$query" failed: $!];
    });

    unless ($success)
    {
        confess $atrack->{transaction_error};
    }

    return $class->new($atrack, $next_id);
}

=head2 _all_values_by_field

  Arg[1]     : column to get
  Arg[2]     : column to order by (optional, default is row_id)
  Arg[3]     : where clause (optional, default is 'current=true')
  Example    ; ATrack::Core_obj->_all_values_by_field($atrack, 'changed')
  Description: Class method. Probably best used internally by inheritors of
               Core_obj. Gives an array reference to all values in a column of
               the database table.
  Returntype : ArrayRef

=cut

sub _all_values_by_field
{
    my ($class, $atrack, $field, $order_by, $where) = @_;
    $order_by ||= 'row_id';
    $where ||= 'current=true';
    return $class->SUPER::_all_values_by_field($atrack, $field, $order_by, $where);
}


=head2 is_name_in_database

  Arg [1]    : name
  Arg [2]    : hierarchy name
  Example    : if (ATrack::Core_obj->is_name_in_database($atrack, $name, $hname)
  Description: Class method. Checks to see if a name or hierarchy name is
               already used in the database table.
  Returntype : boolean

=cut

sub is_name_in_database
{
    my ($class, $atrack, $name, $hname) = @_;
    confess "Need to call with a atrack handle, name, hierarchy name" unless ($atrack && $name && $hname);
    if ($atrack->isa('DBI::db'))
    {
        confess "The interface has changed, expected atrack reference.\n";
    }

    my $table = $class->_class_to_table;

    my $dbh = $atrack->{_dbh};
    my $sql = qq[SELECT ${table}_id FROM $table WHERE current=true AND (name = ? OR hierarchy_name = ?)];
    my $sth = $dbh->prepare($sql);

    my $already_used = 0;
    if ($sth->execute($name, $hname))
    {
        my $data = $sth->fetchrow_hashref;
        if ($data)
        {
            $already_used = 1;
        }
    }
    else
    {
        confess "Cannot retrieve $table by $name: ".$DBI::errstr;
    }

    return $already_used;
}


=head2 update

  Arg [1]    : None
  Example    : $obj->update();
  Description: Update a object whose properties you have changed.  If properties
               haven't changed (i.e. dirty flag is unset) do nothing. Changes
               the changed datestamp to now() on the mysql server (i.e. you
               don't have to set changed yourself, and indeed if you do, it will
               be overridden). Only works if we are the current version - you
               can't update a historical version.
  Returntype : boolean

=cut

sub update
{
    my $self = shift;
    $self->is_current || return 0;

    my $table = $self->_class_to_table;

    my $success = 0;

    if ($self->dirty)
    {
        my $dbh = $self->{_dbh};
        my $currentval = $self->{'unset_current'} ? 'false' : 'true';
        my $row_id; # new row_id if update works
        $success = $self->{atrack}->transaction(sub {
            my $fieldsref = $self->fields_dispatch;
            my @fields = grep {!/^changed$/ && !/^current$/} keys %$fieldsref;

            # Need to unset 'current' flag on current current obj and add
            # the new obj details with the current flag set
            my $updsql = qq[UPDATE $table SET current=false WHERE ${table}_id = ? AND current=true];

            # build insert statement from update fields
            my $addsql = qq[INSERT INTO $table ( ].(join ", ", @fields);
            $addsql .= qq[, changed, current ) ];
            $addsql .= qq[ VALUES ( ].('?,' x scalar @fields).qq[now(),$currentval) ];
            $dbh->do ($updsql, undef, $self->id);
            $dbh->do ($addsql, undef, map {$_->()} @$fieldsref{@fields});
            $row_id = $dbh->{'mysql_insertid'};
        });

        # Remember to update the row_id to the _new_ row_id, as this is an
        # autoinc field
        $self->row_id($row_id) if $success;

        # reinitialize so that changed() will return the correct value. Could
        # probably shortcut and only grab the changed value, but calling
        # _initialize is safer, incase some subclass needs to do something
        # strange in its _initialize. _initialize also unsets dirty flag.
        $self->_initialize($self->id);
    }

    return $success;
}


=head2 delete

  Arg [1]    : none
  Example    : $obj->delete();
  Description: Deletes the current object and all its descendant objects from
               the database.
  Returntype : boolean.

=cut

sub delete
{
    my ($self) = @_;
    my $success = 0;
    my $objs_to_delete = [$self];
    push @$objs_to_delete, @{$self->descendants};
    my %rows_from_table;
    foreach (@$objs_to_delete)
    {
        my $class=ref($_);
        my $table = $class->_class_to_table;
        push @{$rows_from_table{$table}}, $_->id;
    }

    # now delete them all, one table at a time
    my $dbh = $self->{_dbh};
    $success = $self->{atrack}->transaction(sub {
        foreach my $table (keys %rows_from_table)
        {
            my $rows = join ",", @{$rows_from_table{$table}};
            my $delsql = qq[DELETE from $table WHERE ${table}_id in ($rows)];
            $dbh->do ($delsql);
        }
    });

    return $success;
}


=head2 changed

  Arg [1]    : changed (optional)
  Example    : my $changed = $obj->changed();
               $obj->changed('2010-01-04 10:49:10');
  Description: Get/Set for project changed
  Returntype : string

=cut

sub changed
{
    my $self = shift;
    return $self->_get_set('changed', 'string', @_);
}


=head2 descendants

  Arg [1]    : none
  Example    : my $desc_objs = $obj->descendants();
  Description: Returns a ref to an array of all objects that are descendants of
               this object
  Returntype : arrayref of objects

=cut

sub descendants
{
    my $self = shift;
    my @desc;
    foreach my $child_method ($self->_get_child_methods)
    {
        foreach my $obj (@{$self->$child_method})
        {
            push @desc, $obj;
            if ($obj->can('descendants'))
            {
                push @desc, @{$obj->descendants};
            }
        }
    }
    return \@desc;
}


=head2 _get_child_methods

  Arg [1]    : none
  Example    : my @methods = $obj->_get_child_methods();
  Description: For internal use only by inheritors of Core_obj. Gets the methods
               that return a reference to an array of child objects. For use by
               descendants().
  Returntype : array of method names

=cut

sub _get_child_methods
{
    return;
}


=head2 note_id

  Arg [1]    : note_id (optional)
  Example    : my $note_id = $obj->note_id();
               $obj->note_id(104);
  Description: Get/Set for internal ID of the text note on this object
  Returntype : integer

=cut

sub note_id
{
    my $self = shift;
    return $self->_get_set('note_id', 'number', @_);
}


=head2 is_current

  Arg [1]    : boolean for is_current status
  Example    : $obj->is_current(1);
  Description: Get/Set for object being the current
               Note that this sub will return a value of 1 if used to unset
               is_current because is_current has to be 1 for it to be set
               to 0 in update.

  Returntype : boolean

=cut

sub is_current
{
    my ($self,$value) = @_;
    my $retval;

    # to allow unsetting of current (which will make the object 'invisible' to
    # most code), we need to set a special key which update will use to unset
    # current.  Can't just set is_current to 0, as then update will not fire as
    # it won't operate on non-current (i.e. generally historical) objects.

    if (defined $value && $value == 0 && $self->_get_set('is_current'))
    {
        $self->_get_set('unset_current', 'boolean', 1);
        $retval = $self->_get_set('is_current');
    }
    else
    {
        $retval = $self->_get_set('is_current', 'boolean', $value);
    }
    return $retval;
}


=head2 row_id

  Arg [1]    : row_id (optional)
  Example    : my $row_id = $obj->row_id();
               $obj->row_id(104);
  Description: Get/Set for internal ID of the row_id of this object.
               Note that this is a database auto_increment value, so if set, is
               not written to the database.
  Returntype : integer

=cut

sub row_id
{
    my $self = shift;
    return $self->_get_set('row_id', 'number', @_);
}


=head2 row_ids

  Example    : my @row_ids = $obj->row_ids();
  Description: Get all the row_ids for this object. A new row_id is given to an
               object every time it is updated.
  Returntype : integer

=cut

sub row_ids
{
    my $self = shift;

    my $table = $self->_class_to_table;
    my $sql = qq[SELECT row_id FROM $table WHERE ${table}_id = ?];

    my $sth = $self->{_dbh}->prepare($sql);

    if ($sth->execute($self->id))
    {
        my $data = $sth->fetchall_arrayref({}); # return array of hashes
        my %row_ids;
        foreach my $row (@$data)
        {
            $row_ids{$row->{row_id}} = 1;
        }
        my @row_ids = sort { $a <=> $b } keys %row_ids;
        return @row_ids;
    }
    else
    {
        confess "Cannot retrieve $table: ".$DBI::errstr;
    }
}


=head2 list_enum_vals

  Arg [1]    : table name
  Arg [2]    : column name
  Example    : my $vals = $obj->list_enum_vals('library','qc_status');
  Description: retrieves the list of allowed enum values for a column in
               lowercase.  Dies if the column is not of type enum
  Returntype : array ref

=cut

sub list_enum_vals
{
    my ($self, $table, $column) = @_;
    my $dbh = $self->{_dbh};
    my $row = $dbh->selectrow_hashref("SHOW COLUMNS FROM $table LIKE ?", undef, $column);
    my $type = lc($row->{Type});
    unless ($type =~ /^enum/)
    {
        confess "$table:$column is not of type enum";
    }
    $type =~ s/^enum\('//;
    $type =~ s/'\)$//;
    my @vals = split /','/, $type;
    return \@vals;
}


sub _check_status_value
{
    my ($self, $type, $value) = @_;

    if (defined $value)
    {
        my $class = ref($self);
        confess "Could not determine the class name [$class]." unless $class=~/([^:]+)$/;
        my $table = lc($1);

        my $allowed = $allowed_status{$table}->{$type};
        unless ($allowed)
        {
            my %allowed = map {$_ => 1} @{$self->list_enum_vals($table, $type)};
            $allowed = \%allowed;
            $allowed_status{$table}->{$type} = $allowed;
        }
        unless ($allowed->{lc($value)})
        {
            confess "'$value' is not a defined $type";
        }
    }
}


=head2 atrack

  Arg [1]    : atrack (optional)
  Example    : my $atrack = $obj->atrack();
               $obj->atrack($atrack);
  Description: Get/Set for atrack object.  NB you probably really shouldn't be
               setting atrack from outside this object unless you know what
               you're doing.
  Returntype : integer

=cut

sub atrack
{
    my ($self, $atrack) = @_;
    if (defined $atrack and $atrack != $self->{atrack})
    {
        $self->{_dbh} = $atrack->{_dbh};
        $self->{atrack} = $atrack;
    }
    return $self->{atrack};
}

1;
