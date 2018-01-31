=head1 NAME

ATrack::Factory - factory class for getting ATrack objects

=head1 SYNOPSIS

use ATrack::Factory ;

my $atrack = ATrack::Factory->instantiate(database => 'mouse', mode => 'r');

my @database_names = ATrack::Factory->databases();

=head1 DESCRIPTION

A simple factory class that returns ATrack objects to centralise the database
connection information.

Database host, port, username and password are set by environment variables:
VRTRACK_HOST
VRTRACK_PORT
VRTRACK_RO_USER  (for the 'r' mode read-only capable username)
VRTRACK_RW_USER  (for the 'rw' mode read-write capable username)
VRTRACK_PASSWORD

=head1 AUTHOR

Thomas Keane tk2@sanger.ac.uk

=cut

package ATrack::Factory;

use strict;
use warnings;
use Carp qw(confess);
use ATrack::ATrack;

=head2 new

 Title   : instantiate
 Usage   : my $atrack = ATrack::Factory->instantiate(database => 'darwin',
                                                         mode => 'r');
 Function: Ask the factory to return a ATrack object to the database specified.
 Returns : ATrack object
 Args    : database name: a valid ATrack database,
           mode: either 'r' or 'rw' connection

=cut

sub instantiate
{
    my (undef, %args) = @_;

    my $database = $args{database} || confess("A database name must be provided!");
    my $mode = lc($args{mode}) || confess("A connection mode name must be provided!");

    my %details = ATrack::Factory->connection_details($mode);
    $details{database} = $database;

    my $atrack = ATrack::ATrack->new({%details});

    return $atrack;
}

=head2 connection_details

 Title   : connection_details
 Usage   : my %details = ATrack::Factory->connection_details('r');
 Function: Find out what connection details are being used to instantiate().
 Returns : hash with keys: host, port, user, password
 Args    : mode string (r|rw)

=cut

sub connection_details
{
    my (undef, $mode) = @_;

    $mode = lc($mode) || confess("A connection mode name must be provided!");

    confess("Invalid connection mode (r or rw valid): $mode\n") unless $mode =~ /^(?:r|rw)$/;

    my $READ_USER = $ENV{VRTRACK_RO_USER};
    my $WRITE_USER = $ENV{VRTRACK_RW_USER};
    my $WRITE_PASS = $ENV{VRTRACK_PASSWORD};
    my $user = $mode eq 'rw' ? $WRITE_USER : ($READ_USER || $WRITE_USER);
    my $pass = $mode eq 'rw' ? $WRITE_PASS : ($READ_USER ? '' : $WRITE_PASS);

    return (
        host => $ENV{VRTRACK_HOST},
        port => $ENV{VRTRACK_PORT} || $ATrack::ATrack::DEFAULT_PORT,
        user => $user,
        password => $pass
    );
}

=head2 databases

 Title   : databases
 Usage   : my @db_names = ATrack::Factory->databases();
 Function: Find out what databases are available to instantiate. Excludes any
           test databases by default.
 Returns : list of strings
 Args    : boolean, which if true will also return test databases and databases
           with old schema versions (default false). Optionally a second
           boolean, which if true will only return databases that have old
           schema versions (the first boolean must be true for this to work)

=cut

sub databases
{
    my (undef, $include_test_and_old_dbs, $only_old) = @_;

    my %cd = ATrack::Factory->connection_details('r');

    my @databases = grep(s/^DBI:mysql://, DBI->data_sources("mysql", \%cd));

    # we skip information_schema and any test databases
    @databases = grep(!/^information_schema/, @databases);
    unless ($include_test_and_old_dbs)
    {
        @databases = grep(!/test/, @databases);
    }

    # we have to actually check that these databases are atrack databases with
    # the correct schema version
    my $schema_version = ATrack::ATrack::SCHEMA_VERSION;
    my %expected_tables;
    foreach (ATrack::ATrack->schema())
    {
        if (/CREATE TABLE `(.+?)`/i || /CREATE VIEW (\S+)/i)
        {
            $expected_tables{$1} = 1;
        }
    }
    my @dbs;
    DB: foreach my $db (@databases)
    {
        my $dbh = DBI->connect("dbi:mysql:$db;host=$cd{host};port=$cd{port}", $cd{user}, $cd{password}, { RaiseError => 0 });
        unless ($dbh)
        {
            warn("Could not connect to database $db to check if it was a ATrack database");
            next;
        }

        my %tables = map { s/`//g; s/^$db\.//; $_ => 1 } $dbh->tables();

        next DB unless exists $tables{schema_version};
        foreach my $table (keys %tables)
        {
            next DB unless exists $expected_tables{$table}; # we're assuming no schema update will ever drop a table
        }

        my $sql = qq[ SELECT * FROM schema_version ];
        my $rows = $dbh->selectall_arrayref($sql);
        my $is_old = $rows->[0]->[0] < $schema_version;
        unless ($include_test_and_old_dbs)
        {
            next unless $rows->[0]->[0] == $schema_version;
        }

        if (! $only_old || $only_old && $is_old)
        {
            push(@dbs, $db);
        }
    }

    return @dbs;
}

1;
