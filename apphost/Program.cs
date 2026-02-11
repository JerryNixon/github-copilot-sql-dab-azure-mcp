// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

var builder = DistributedApplication.CreateBuilder(args);

// Fail fast if config.js has placeholder values
var configPath = Path.GetFullPath(Path.Combine(builder.AppHostDirectory, @"..\web\config.js"));
if (File.Exists(configPath) && File.ReadAllText(configPath).Contains("__CLIENT_ID__"))
{
    throw new InvalidOperationException(
        "web/config.js has placeholder values. Run: ./azure/entra-setup.ps1");
}

// Fail fast if dab-config.json has placeholder values
var dabConfigPath = Path.GetFullPath(Path.Combine(builder.AppHostDirectory, @"..\api\dab-config.json"));
if (File.Exists(dabConfigPath) && File.ReadAllText(dabConfigPath).Contains("__AUDIENCE__"))
{
    throw new InvalidOperationException(
        "api/dab-config.json has placeholder values. Run: ./azure/entra-setup.ps1");
}

var options = new
{
    SqlDatabase = "TodoDb",
    DabConfig = Path.GetFullPath(Path.Combine(builder.AppHostDirectory, @"..\api\dab-config.json")),
    WebRoot = Path.GetFullPath(Path.Combine(builder.AppHostDirectory, @"..\web")),
    DabImage = "1.7.83-rc",
    SqlCmdrImage = "latest"
};

var sqlPassword = builder.AddParameter("sql-password", secret: true);

var sqlServer = builder
    .AddSqlServer("sql-server", sqlPassword)
    .WithDataVolume("sql-data")
    .WithEnvironment("ACCEPT_EULA", "Y")
    .WithLifetime(ContainerLifetime.Persistent);

var sqlDatabase = sqlServer
    .AddDatabase(options.SqlDatabase)
    .WithCreationScript(File.ReadAllText(Path.Combine(builder.AppHostDirectory, @"..\database.sql")));

var apiServer = builder
    .AddContainer("data-api", image: "azure-databases/data-api-builder", tag: options.DabImage)
    .WithImageRegistry("mcr.microsoft.com")
    .WithBindMount(source: options.DabConfig, target: "/App/dab-config.json", isReadOnly: true)
    .WithHttpEndpoint(targetPort: 5000, port: 5000, name: "http")
    .WithEnvironment("MSSQL_CONNECTION_STRING", sqlDatabase)
    .WithUrls(context =>
    {
        context.Urls.Clear();
        context.Urls.Add(new() { Url = "/graphql", DisplayText = "GraphQL", Endpoint = context.GetEndpoint("http") });
        context.Urls.Add(new() { Url = "/swagger", DisplayText = "Swagger", Endpoint = context.GetEndpoint("http") });
        context.Urls.Add(new() { Url = "/health", DisplayText = "Health", Endpoint = context.GetEndpoint("http") });
    })
    .WithOtlpExporter()
    .WithParentRelationship(sqlDatabase)
    .WithHttpHealthCheck("/health")
    .WaitFor(sqlDatabase);

var sqlCommander = builder
    .AddContainer("sql-cmdr", "jerrynixon/sql-commander", options.SqlCmdrImage)
    .WithImageRegistry("docker.io")
    .WithHttpEndpoint(targetPort: 8080, name: "http")
    .WithEnvironment("ConnectionStrings__db", sqlDatabase)
    .WithUrls(context =>
    {
        context.Urls.Clear();
        context.Urls.Add(new() { Url = "/", DisplayText = "Commander", Endpoint = context.GetEndpoint("http") });
    })
    .WithParentRelationship(sqlDatabase)
    .WithHttpHealthCheck("/health")
    .WaitFor(sqlDatabase);

var webApp = builder
    .AddContainer("web-app", "nginx", "alpine")
    .WithImageRegistry("docker.io")
    .WithBindMount(source: options.WebRoot, target: "/usr/share/nginx/html", isReadOnly: true)
    .WithHttpEndpoint(targetPort: 80, port: 5173, name: "http")
    .WithUrls(context =>
    {
        context.Urls.Clear();
        context.Urls.Add(new() { Url = "/", DisplayText = "Web App", Endpoint = context.GetEndpoint("http") });
    })
    .WaitFor(apiServer);

await builder.Build().RunAsync();
