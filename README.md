This is a script created to generate files for entities using EntityFrameworkCore.
Call EntityGenerator from Powershell and give the name of an entity to generate all files.

The config.cfg file has the following keys:

`TargetRootPath` : The path (relative or absolute) to the root of the ASPNetCore project;
`DbContext` : The name of the DbContext class used on the project;

You can use the `-CreateDbContext` option to generate the DbContext file with the necessary format for the script to work.