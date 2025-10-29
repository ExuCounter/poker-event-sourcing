### Adding Ecto Schemas
1. Create schema module in the appropriate context directory
   - Name pattern: `Poker.<Context>.Schema.<ModelName>` (e.g., `Poker.Accounts.Schemas.User`, `Poker.Events.Schemas.Event`)
   - Place in `poker/lib/<context>/schemas/` directory
   - Use `use Poker, :schema` for common schema functionality
   - Define changesets within the schema file
   - Changeset function naming: `changeset` or `*_changeset` (e.g., `create_changeset`, `update_changeset`)
   - Use built-in `Ecto.Enum` for enum fields

### Adding Ecto Queries
1. Create queries module in the appropriate context directory
   - Name pattern: `Poker.<Context>.Queries` (e.g., `Poker.Accounts.Queries`, `Poker.Events.Queries`)
   - Place in `poker/lib/<context>/queries.ex`
   - Use `use Poker, :query` for common query functionality
   - Use Composite for complex filtering with multiple parameters

### Git Commit Conventions
Use Conventional Commits format for all commit messages:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `style:` Code style changes (formatting, etc.)
- `refactor:` Code refactoring
- `perf:` Performance improvements
- `test:` Test additions or changes
- `chore:` Build process or auxiliary tool changes
- Example: `feat: create events schema`

### Creating Database Migrations
```bash
mix ecto.gen.migration migration_name
# Edit the migration file in priv/repo/migrations/
mix ecto.migrate
```

### Adding Background Jobs
1. Create job module in the appropriate context directory
   - Name pattern: `Poker.<Context>.Jobs.<Action>` (e.g., `Poker.Accounts.Jobs.UserUpdate`, `Poker.Table.Jobs.StartTable`)
   - Place in `poker/<context>/jobs/` directory
   - Use descriptive names that clearly indicate the job's purpose
2. Use `Oban.Worker` with `args_schema` for argument validation
3. Enqueue with `Oban.insert/2`
