// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

#:sdk Aspire.AppHost.Sdk@13.0.0
#:package Aspire.Hosting.SqlServer@13.0.0
#:package CommunityToolkit.Aspire.Hosting.SqlDatabaseProjects@9.8.1-beta.420
#:package CommunityToolkit.Aspire.Hosting.Azure.DataApiBuilder@9.8.1-beta.420
#:package CommunityToolkit.Aspire.Hosting.McpInspector@9.8.0

var builder = DistributedApplication.CreateBuilder(args);

// Fail fast if config.js has placeholder values
var configPath = Path.GetFullPath(@"web\config.js");
if (File.Exists(configPath) && File.ReadAllText(configPath).Contains("__CLIENT_ID__"))
{
    throw new InvalidOperationException(
        "web/config.js has placeholder values. Run: azd hooks run preprovision");
}

// Fail fast if dab-config.json has placeholder values
var dabConfigPath = Path.GetFullPath(@"api\dab-config.json");
if (File.Exists(dabConfigPath) && File.ReadAllText(dabConfigPath).Contains("__AUDIENCE__"))
{
    throw new InvalidOperationException(
        "api/dab-config.json has placeholder values. Run: azd hooks run preprovision");
}

var options = new
{
    SqlDatabase = "TodoDb",
    DabConfig = @"Api\dab-config.json",
    DabImage = "1.7.83-rc",
    SqlCmdrImage = "latest"
};

var sqlServer = builder
    .AddSqlServer("sql-server")
    .WithDataVolume("sql-data")
    .WithEnvironment("ACCEPT_EULA", "Y")
    .WithLifetime(ContainerLifetime.Persistent);

var sqlDatabase = sqlServer
    .AddDatabase(options.SqlDatabase);

var sqlDatabaseWithSchema = sqlDatabase
    .WithSqlProject(new FileInfo(@"database\database.sqlproj").FullName);

var dabServer = builder
    .AddContainer("data-api", image: "azure-databases/data-api-builder", tag: options.DabImage)
    .WithImageRegistry("mcr.microsoft.com")
    .WithBindMount(source: new FileInfo(options.DabConfig).FullName, target: "/App/dab-config.json", isReadOnly: true)
    .WithHttpEndpoint(targetPort: 5000, name: "http")
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
    .WaitFor(sqlDatabaseWithSchema);

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
    .WaitFor(sqlDatabaseWithSchema);

var mcpInspector = builder
    .AddMcpInspector("mcp-inspector")
    .WithMcpServer(dabServer)
    .WithParentRelationship(dabServer)
    .WithEnvironment("NODE_TLS_REJECT_UNAUTHORIZED", "0")
    .WaitFor(dabServer)
    .WithUrls(context =>
    {
        context.Urls.First().DisplayText = "Inspector";
    });

await builder.Build().RunAsync();
