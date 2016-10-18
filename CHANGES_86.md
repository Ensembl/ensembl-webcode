# Release 86 Webcode changes

## Session code changes

The way the ensembl webcode interacts with session and accounts databases and saves user configurations
is changed. The code interacting with mysql database is removed and the webcode now uses ensembl-orm API
to access session database. The database schema is also changed. Before 86, there were three tables each
in the `DATABASE_SESSION` and `DATABASE_ACCOUNTS` database that would save user records.
* `record`: To save records of the logged in user like bookmarks, history etc.
* `session_record`: To save records linked to current session id, eg. DataTable sorting, NewTable configurations etc.
* `configuration_details`/`configuration_records`: To save ImageConfig and ViewConfig changes made by the user (againt the session id)

All these tables are now merged into a single table called `all_record`. There's a
[script available in webcode] (https://github.com/Ensembl/ensembl-webcode/blob/release/86/utils/merge_all_records_86.pl)
that will move all the records from above four tables to all_tables. Run the script with `--help` options to know more
about it's command line options.

### RecordManager and RecordSet

For each request, all the records belonging to the current session (`ORM::EnsEMBL::DB::Session::Object::Record`) or the
logged in user (`ORM::EnsEMBL::DB::Accounts::Object::Record`) are retrieved from the databases in the beginning and then
further requests to individual records by the code are handled by the `EnsEMBL::Web::RecordManager` object. The code now
processes single MySQL `TRANSACTION` per request - `BEGIN`s transaction when a session id / user id is retrieved and then
`COMMIT`s it before the Controller returns final response to the Apache request.

Both `EnsEMBL::Web::Session` and `EnsEMBL::Web::User` inherit from `EnsEMBL::Web::RecordManager` thus providing same methods
to both to access records.

`EnsEMBL::Web::RecordSet` is a filterable list of all the available records for the session/user.

## Apache handlers and web controllers changes

The Apache handlers (modules in `EnsEMBL::Web::Apache::*`) have been rewritten to pass the current Apache request object
`Apache2::RequestRec` to the Controllers and Hub. The Controller and Hub get created only once per request and all the
cookie/session/user/db initialisation code is only run once the Hub object is created. Use of `EnsEMBL::Web::Exceptions` has
been incorporated into Apache handlers, controllers and Hub to simplify exception handling. The overall structure of Apache
and Controller modules is modified to make it easy to write plugin for these modules using [`previous`]
(https://github.com/Ensembl/ensembl-webcode/blob/release/86/conf/previous.pm) syntax.

## ImageConfig and ViewConfig

`EnsEMBL::Web::Imageconfig` and `EnsEMBL::Web::ViewConfig` now both inherit from `EnsEMBL::Web::Config` that has an implicit
mechanism to cache configs in memcached based on the `type` and `code` of the Image/ViewConfig. All the modules that inherit from
`EnsEMBL::Web::Imageconfig` or `EnsEMBL::Web::ViewConfig` have been rewritten according the base module changes.

Three extensions modules as below are split out of `EnsEMBL::Web::ImageConfig` modules to make the code manageable.
* `EnsEMBL::Web::ImageConfigExtension::Nodes`: Code that deals with Tree Nodes for ImageConfig Tree.
* `EnsEMBL::Web::ImageConfigExtension::Tracks`: Code that deals with all the default available tracks.
* `EnsEMBL::Web::ImageConfigExtension::UserTracks`: Code that deals with all the user uploaded/attached data tracks including TrackHubs.

## Cookie code changes

The `EnsEMBL::Web::Cookie` package that deals with web cookies is also modified to remove the use of `CGI` and use `Apache2::RequestRec`
directly to read/set cookies.
