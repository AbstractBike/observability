// Dashboard Metadata & Versioning
//
// Provides standardized metadata for all dashboards.
// Enables versioning, deprecation tracking, and migration paths.

{
  // Standard dashboard version format: "YYYY-MM-DD-PATCH"
  // Bumped when dashboard structure or queries change significantly

  // Metadata for dashboard versioning and tracking
  withMetadata(version, author, lastModified, description=''):
    {
      __metadata: {
        version: version,
        author: author,
        lastModified: lastModified,
        description: description,
      },
    },

  // Version string helper
  // Usage: c.version('2026-03-04', 1)
  version(date, patch=0):
    date + '-' + patch,

  // Deprecation marker - for dashboards being phased out
  deprecated(replacement_uid, migration_notes=''):
    {
      __deprecated: {
        replacement_uid: replacement_uid,
        migration_notes: migration_notes,
        deprecation_date: '2026-03-04',
      },
    },

  // Dashboard tags standard
  // Always include: environment, category, and domain
  standardTags(environment='production', category='observability', domain='core'):
    [
      environment,
      category,
      domain,
    ],
}
