param(
    [Parameter(Mandatory=$true)][string]$EntityName,
    [switch]$CreateDbContext
)

$Config = Get-Content .\config.cfg

$Variables = @{}

foreach($Option in $Config)
{
    if($Option -eq "")
    {
        continue
    }
    $x = $Option.Split("=")
    $Variables.Add($x[0], $x[1])
}

if($PSBoundParameters.ContainsKey("CreateDbContext"))
{
    New-Item -Path "$($Variables["TargetRootPath"])\Core\$($EntityName).cs" -ItemType File -Force
    Write-Output @"
using Api.Domain.Models;
using Api.Core.Mapping;
using Microsoft.EntityFrameworkCore;

namespace Api.Core;

//Do not erase comments, as they are used by the generation script
public class $($EntityName) : DbContext
{
    public $($EntityName)() {}

    public $($EntityName)(DbContextOptions<$($EntityName)> options)
    : base(options)
    {}

    //DbSets

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        //Mapping
    }
}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Core\$($EntityName).cs"

    $Variables["DbContext"] = $EntityName

    $ConfigOut = ""
    foreach($item in $Variables.Keys)
    {
        $ConfigOut += "$($item)=$($Variables[$item])`n"
    }

    Write-Output $ConfigOut.TrimEnd("`r", "`n") | Out-File ".\config.cfg"

    return
}

$EntityNameLower = $EntityName.toLower()

New-Item -Path "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName).cs" -ItemType File -Force
New-Item -Path "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName)DTO.cs" -ItemType File -Force
New-Item -Path "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName)Payloads.cs" -ItemType File -Force
New-Item -Path "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Repositories\I$($EntityName)Repository.cs" -ItemType File -Force
New-Item -Path "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Services\I$($EntityName)Service.cs" -ItemType File -Force
New-Item -Path "$($Variables["TargetRootPath"])\Core\Entities\$($EntityName)\Mapping\$($EntityName)ClassMap.cs" -ItemType File -Force
New-Item -Path "$($Variables["TargetRootPath"])\Core\Entities\$($EntityName)\Repositories\$($EntityName)Repository.cs" -ItemType File -Force
New-Item -Path "$($Variables["TargetRootPath"])\Core\Entities\$($EntityName)\Services\$($EntityName)Service.cs" -ItemType File -Force

Write-Output @"
namespace Api.Domain.Models;

public class $($EntityName) : IEntity
{

}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName).cs"

Write-Output @"
namespace Api.Domain.Models;

public record $($EntityName)DTO(
    int Id
)
{
    public static $($EntityName)DTO Map($($EntityName) obj)
    {
        return new $($EntityName)DTO(
            obj.Id
        );
    }
}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName)DTO.cs"

Write-Output @"
using System.ComponentModel.DataAnnotations;

namespace Api.Domain.Models;

public class $($EntityName)CreatePayload
{

}

public class $($EntityName)UpdatePayload
{

}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName)Payloads.cs"

Write-Output @"
using Api.Domain.Models;

namespace Api.Domain.Repositories;

public interface I$($EntityName)Repository : IRepository<$($EntityName)>
{

}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Repositories\I$($EntityName)Repository.cs"

Write-Output @"
using Api.Domain.Models;

namespace Api.Domain.Services;

public interface I$($EntityName)Service : IService<$($EntityName)>
{
    
}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Services\I$($EntityName)Service.cs"

Write-Output @"
using Api.Domain.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace Api.Core.Mapping;

public class $($EntityName)ClassMap : IEntityTypeConfiguration<$($EntityName)>
{
    public void Configure(EntityTypeBuilder<$($EntityName)> builder)
    {
        builder.HasKey($($EntityNameLower) => $($EntityNameLower).Id)
            .HasName("PK_____$($EntityName)");

        builder.ToTable("tb_$($EntityNameLower)");
    }
}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Core\Entities\$($EntityName)\Mapping\$($EntityName)ClassMap.cs"

Write-Output @"
using Api.Domain.Models;
using Api.Domain.Repositories;

namespace Api.Core.Repositories;

public class $($EntityName)Repository($($Variables["DbContextName"]) context)
    : BaseRepository<$($EntityName)>(context), I$($EntityName)Repository
{
    
}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Core\Entities\$($EntityName)\Repositories\$($EntityName)Repository.cs"

Write-Output @"
using Api.Core.Repositories;
using Api.Domain.Models;
using Api.Domain.Services;

namespace Api.Core.Services;

public class $($EntityName)Service($($EntityName)Repository repository)
    : BaseService<$($EntityName)>(repository), I$($EntityName)Service
{

}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Core\Entities\$($EntityName)\Services\$($EntityName)Service.cs"

$Content = Get-Content "$($Variables["TargetRootPath"])\Core\$($Variables["DbContext"]).cs"
$ContentOut = ""

foreach($line in $Content)
{
    $ContentOut += "$line`n"
    if($line.Trim() -eq "//DbSets")
    {
        $ContentOut += "    public virtual DbSet<$($EntityName)> $($EntityName)List {get; set;}`n"
    }elseif($line.Trim() -eq "//Mapping")
    {
        $ContentOut += "        modelBuilder.ApplyConfiguration(new $($EntityName)ClassMap());`n"
    }
}

Write-Output $ContentOut.TrimEnd("`r", "`n") | Out-File -FilePath "$($Variables["TargetRootPath"])\Core\$($Variables["DbContext"]).cs"