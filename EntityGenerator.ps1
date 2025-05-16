param(
    [string]$EntityName = "",
    [switch]$CreateDbContext,
    [switch]$ImplementEntity,
    [switch]$GenerateExtensions,
    [switch]$UseDTO,
    [switch]$MapFK,
    [switch]$SkipMap
)

$Config = Get-Content .\config.cfg

$BuiltInTypes = @("bool", "byte", "sbyte", "char", "decimal", "double", "float", "int", "uint", "nint", "nuint", "long", "ulong", "short", "ushort", "string")

$Variables = @{}

function ToSnake
{
    param(
        [Parameter(Mandatory=$true)][string]$Value
    )

    for($i = 1; $i -lt $Value.Length; $i++)
    {
        if($Value[$i] -cmatch '[A-Z]')
        {
            $Value = $Value.Substring(0, $i) + "_" + $Value.Substring($i)
            $i++
        }
    }
    $Value = $Value.ToLower()

    return $Value
}

foreach($Option in $Config)
{
    if($Option -eq "")
    {
        continue
    }
    $x = $Option.Split("=")
    $Variables.Add($x[0], $x[1])
}

if($PSBoundParameters.ContainsKey("GenerateExtensions"))
{
    New-Item -Path "$($Variables["TargetRootPath"])\Configuration\ConfigureRepositoriesExtension.cs" -ItemType File -Force
    New-Item -Path "$($Variables["TargetRootPath"])\Configuration\ConfigureServicesExtension.cs" -ItemType File -Force

    Write-Output @"
using Api.Core.Repositories;
using Api.Domain.Models;
using Api.Domain.Repositories;

namespace Api.Configuration;

//Do not erase comments, as they are used by the generation script
public static partial class ServiceCollectionExtension
{
    public static IServiceCollection ConfigureEntityRepositories(this IServiceCollection services)
    {
        //Repositories
        return services;
    }
}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Configuration\ConfigureRepositoriesExtension.cs"

    Write-Output @"
using Api.Core.Services;
using Api.Domain.Models;
using Api.Domain.Services;

namespace Api.Configuration;

//Do not erase comments, as they are used by the generation script
public static partial class ServiceCollectionExtension
{
    public static IServiceCollection ConfigureEntityServices(this IServiceCollection services)
    {
        //Services
        return services;
    }
}
"@ | Out-File -FilePath "$($Variables["TargetRootPath"])\Configuration\ConfigureServicesExtension.cs"
}

if($PSBoundParameters.ContainsKey("CreateDbContext"))
{

    if($EntityName -eq ""){$EntityName = $Variables["DbContext"]}
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

if($EntityName -eq ""){return}

$EntityNameLower = ToSnake $EntityName

if($PSBoundParameters.ContainsKey("ImplementEntity"))
{
    $Req = [System.Collections.ArrayList]::new()
    $Type = [System.Collections.ArrayList]::new()
    $VarName = [System.Collections.ArrayList]::new()
    $Reading = $false

    $EntityFile = Get-Content "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName).cs"
    foreach($line in $EntityFile)
    {
        if($Reading -eq $false -and $line -cmatch "{")
        {
            $Reading = $true
            continue
        }elseif($Reading -eq $true -and $line.Trim() -eq "}")
        {
            $Reading = $false
        }

        if($Reading)
        {

            $end = $line.IndexOfAny((';', '{'))
            if($end -ge 1)
            {
                if($line -cmatch " required ")
                {
                    $Req.Add($true)
                }else
                {
                    $Req.Add($false)
                }
                $start = $line.Substring(0, $end - 1).TrimEnd().LastIndexOf(' ')
                $VarName.Add($line.Substring($start + 1, $end - $start - 1).Trim())

                $end = $start
                $start = $line.Substring(0, $end - 1).TrimEnd().LastIndexOf(' ')
                $Type.Add($line.Substring($start + 1, $end - $start - 1).Trim(" ", "?"))
            }
        }
    }

    $File = Get-Content "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName)DTO.cs" -Raw

    $x = [regex]::Match($File, "public record $($EntityName)DTO\(")
    $start = $x.Index + $x.Length
    $scope = 1
    $y = $start

    while($true)
    {
        $y++
        if($File[$y] -eq '(')
        {
            $scope++
        }elseif($File[$y] -eq ')')
        {
            $scope--
            if($scope -eq 0)
            {
                break
            }
        }
    }

    $File = $File.Remove($start, $y - ($start + 1))

    $x = $File.Substring(0, $start) + "`r`n    int Id,"
    for($i = 0; $i -lt $VarName.Count; $i++)
    {
        $IsList = $false
        $TrueType = $Type[$i]

        if($Type[$i] -cmatch "[(ICollection)(IEnumerable)]<.*>")
        {
            $IsList = $true
            $open = $Type[$i].LastIndexOf('<') + 1
            $close = $Type[$i].IndexOf('>')
            $TrueType = $Type[$i].Substring($open, $close - $open)
        }elseif($Type[$i] -cmatch ".*\[\]")
        {
            $IsList = $true
            $TrueType = $Type[$i].Substring(0, $Type[$i].Length - 2)
        }

        if($BuiltInTypes -contains $TrueType)
        {
            if($IsList)
            {
                $x += "`r`n    IEnumerable<$($TrueType)> $($VarName[$i]),"
            }else
            {
                $x += "`r`n    $($TrueType)"

                if($Req[$i] -eq $false)
                {
                    $x += "?"
                }

                $x += " $($VarName[$i]),"
            }
        }elseif(Test-Path "$($Variables["TargetRootPath"])\Domain\Entities\$($TrueType)\Models\$($TrueType).cs")
        {
            if($PSBoundParameters.ContainsKey("UseDTO"))
            {
                if($IsList)
                {
                    $x += "`r`n    IEnumerable<$($TrueType)DTO> $($VarName[$i]),"
                }else
                {
                    $x += "`r`n    $($TrueType)DTO"

                    if($Req[$i] -eq $false)
                    {
                        $x += "?"
                    }

                    $x += " $($VarName[$i]),"
                }
            }else
            {
                if($IsList)
                {
                    $x += "`r`n    IEnumerable<int> $($VarName[$i]),"
                }else
                {
                    $x += "`r`n    int"

                    if($Req[$i] -eq $false)
                    {
                        $x += "?"
                    }

                    $x += " $($VarName[$i])Id,"
                }
            }
        }
    }

    $File = $x.Substring(0, $x.Length - 1) + "`r`n" + $File.Substring($start + 1)

    # Parte dois

    $x = [regex]::Match($File, "return new $($EntityName)DTO\(")
    $start = $x.Index + $x.Length
    $scope = 1
    $y = $start

    while($true)
    {
        $y++
        if($File[$y] -eq '(')
        {
            $scope++
        }elseif($File[$y] -eq ')')
        {
            $scope--
            if($scope -eq 0)
            {
                break
            }
        }
    }

    $File = $File.Remove($start, $y - ($start + 1))

    $x = $File.Substring(0, $start) + "`r`n            obj.Id,"
    for($i = 0; $i -lt $VarName.Count; $i++)
    {
        $IsList = $false
        $TrueType = $Type[$i]

        if($Type[$i] -cmatch "[(ICollection)(IEnumerable)]<.*>")
        {
            $IsList = $true
            $open = $Type[$i].LastIndexOf('<') + 1
            $close = $Type[$i].IndexOf('>')
            $TrueType = $Type[$i].Substring($open, $close - $open)
        }elseif($Type[$i] -cmatch ".*\[\]")
        {
            $IsList = $true
            $TrueType = $Type[$i].Substring(0, $Type[$i].Length - 2)
        }

        if($BuiltInTypes -contains $TrueType)
        {
            $x += "`r`n            obj.$($VarName[$i]),"
        }elseif(Test-Path "$($Variables["TargetRootPath"])\Domain\Entities\$($TrueType)\Models\$($TrueType).cs")
        {
            if($PSBoundParameters.ContainsKey("UseDTO"))
            {
                if($IsList)
                {
                    $x += "`r`n            obj.$($VarName[$i]).Select(item => $($TrueType)DTO.Map(item)),"
                }else
                {
                    $x += "`r`n            $($TrueType)DTO.Map(obj.$($VarName[$i]))"
                }
            }else
            {
                if($IsList)
                {
                    $x += "`r`n            obj.$($VarName[$i]).Select(item => item.Id),"
                }else
                {
                    $x += "`r`n            obj.$($VarName[$i]).Id,"
                }
            }
        }
    }

    $File = $x.Substring(0, $x.Length - 1) + "`r`n        " + $File.Substring($start + 1)

    Write-Output $File.TrimEnd("`r", "`n") | Out-File -FilePath "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName)DTO.cs"

    $File = Get-Content "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName)Payloads.cs" -Raw

    $x = [regex]::Match($File, "public class $($EntityName)CreatePayload")
    $y = $x.Index + $x.Length

    while($true)
    {
        $y++
        if($File[$y] -eq '{')
        {
            break
        }
    }
    $start = $y + 1
    $scope = 1

    while($true)
    {
        $y++
        if($File[$y] -eq '{')
        {
            $scope++
        }elseif($File[$y] -eq '}')
        {
            $scope--
            if($scope -eq 0)
            {
                break
            }
        }
    }

    $File = $File.Remove($start, $y - ($start + 1))

    $x = $File.Substring(0, $start)
    for($i = 0; $i -lt $VarName.Count; $i++)
    {
        $IsList = $false
        $TrueType = $Type[$i]

        if($Type[$i] -cmatch "[(ICollection)(IEnumerable)]<.*>")
        {
            $IsList = $true
            $open = $Type[$i].LastIndexOf('<') + 1
            $close = $Type[$i].IndexOf('>')
            $TrueType = $Type[$i].Substring($open, $close - $open)
        }elseif($Type[$i] -cmatch ".*\[\]")
        {
            $IsList = $true
            $TrueType = $Type[$i].Substring(0, $Type[$i].Length - 2)
        }

        if($BuiltInTypes -contains $TrueType)
        {
            if($IsList)
            {
                $x += "`r`n    [Required]`r`n    public required IEnumerable<$($TrueType)> $($VarName[$i])"
            }else
            {
                if($Req[$i])
                {
                    $x += "`r`n    [Required]`r`n    public required $($TrueType) $($VarName[$i])"
                }else
                {
                    $x += "`r`n    public $($TrueType)? $($VarName[$i])"
                }
            }
            $x += " {get;set;}"
        }elseif(Test-Path "$($Variables["TargetRootPath"])\Domain\Entities\$($TrueType)\Models\$($TrueType).cs")
        {
            if($IsList)
            {
                $x += "`r`n    [Required]`r`n    public required IEnumerable<int> $($VarName[$i])"
            }else
            {
                if($Req[$i])
                {
                    $x += "`r`n    [Required]`r`n    public required int $($VarName[$i])Id"
                }else
                {
                    $x += "`r`n    public int? $($VarName[$i])Id"
                }
            }
            $x += " {get;set;}"
        }
    }

    $File = $x + "`r`n" + $File.Substring($start + 1)

    $x = [regex]::Match($File, "public class $($EntityName)UpdatePayload")
    $y = $x.Index + $x.Length

    while($true)
    {
        $y++
        if($File[$y] -eq '{')
        {
            break
        }
    }
    $start = $y + 1
    $scope = 1

    while($true)
    {
        $y++
        if($File[$y] -eq '{')
        {
            $scope++
        }elseif($File[$y] -eq '}')
        {
            $scope--
            if($scope -eq 0)
            {
                break
            }
        }
    }

    $File = $File.Remove($start, $y - ($start + 1))

    $x = $File.Substring(0, $start)
    for($i = 0; $i -lt $VarName.Count; $i++)
    {
        $IsList = $false
        $TrueType = $Type[$i]

        if($Type[$i] -cmatch "[(ICollection)(IEnumerable)]<.*>")
        {
            $IsList = $true
            $open = $Type[$i].LastIndexOf('<') + 1
            $close = $Type[$i].IndexOf('>')
            $TrueType = $Type[$i].Substring($open, $close - $open)
        }elseif($Type[$i] -cmatch ".*\[\]")
        {
            $IsList = $true
            $TrueType = $Type[$i].Substring(0, $Type[$i].Length - 2)
        }

        if($BuiltInTypes -contains $TrueType)
        {
            if($IsList)
            {
                $x += "`r`n    public IEnumerable<$($TrueType)> $($VarName[$i])"
            }else
            {
                $x += "`r`n    public $($TrueType)? $($VarName[$i])"
            }

            $x += " {get;set;}"

            if($i -ge $VarName.Count - 1)
            {
                $x += "`r`n"
            }
        }elseif(Test-Path "$($Variables["TargetRootPath"])\Domain\Entities\$($TrueType)\Models\$($TrueType).cs")
        {
            if($IsList)
            {
                $x += "`r`n    public IEnumerable<int> $($VarName[$i])"
            }else
            {
                $x += "`r`n    public int? $($VarName[$i])Id"
            }

            $x += " {get;set;}"

            if($i -ge $VarName.Count - 1)
            {
                $x += "`r`n"
            }
        }
    }

    $File = $x + "`r`n" + $File.Substring($start + 1)

    Write-Output $File.TrimEnd("`r", "`n") | Out-File -FilePath "$($Variables["TargetRootPath"])\Domain\Entities\$($EntityName)\Models\$($EntityName)Payloads.cs"
    
    if($PSBoundParameters.ContainsKey("SkipMap")){return}

    $File = Get-Content "$($Variables["TargetRootPath"])\Core\Entities\$($EntityName)\Mapping\$($EntityName)ClassMap.cs" -Raw

    $x = "builder.ToTable(`"tb_$($EntityNameLower)`");"
    $a = $File.IndexOf($x)
    $y = $a + $x.Length

    $start = $y
    $scope = 1

    while($true)
    {
        $y++
        if($File[$y] -eq '}')
        {
            break
        }
    }

    $File = $File.Remove($start, $y - ($start + 1))

    $x = $File.Substring(0, $start)
    for($i = 0; $i -lt $VarName.Count; $i++)
    {
        $IsList = $false
        $TrueType = $Type[$i]

        if($Type[$i] -cmatch "[(ICollection)(IEnumerable)]<.*>")
        {
            $IsList = $true
            $open = $Type[$i].LastIndexOf('<') + 1
            $close = $Type[$i].IndexOf('>')
            $TrueType = $Type[$i].Substring($open, $close - $open)
        }elseif($Type[$i] -cmatch ".*\[\]")
        {
            $IsList = $true
            $TrueType = $Type[$i].Substring(0, $Type[$i].Length - 2)
        }

        if($BuiltInTypes -contains $TrueType -and $IsList -eq $false)
        {
            $x += "`r`n"
            $x += @"

        builder.Property($($EntityNameLower) => $($EntityNameLower).$($VarName[$i]))
            .HasColumnName("$(ToSnake $VarName[$i])")
"@
            if($TrueType -eq "string")
            {
                $x += "`r`n            .HasMaxLength(255)"
            }
            $x += ";"
        }
    }

    $File = $x + "`r`n    " + $File.Substring($start + 1)

    if($PSBoundParameters.ContainsKey("MapFK"))
    {
        $x = ".HasName(`"PK_____$($EntityName)`");"

        $FKStart = $File.IndexOf($x) + $x.Length
        $File = $File.Remove($FKStart, $a - ($FKStart + 1))

        $x = $File.Substring(0, $FKStart) + "`r`n"
        for($i = 0; $i -lt $VarName.Count; $i++)
        {
            $IsList = $false
            $TrueType = $Type[$i]

            if($Type[$i] -cmatch "[(ICollection)(IEnumerable)]<.*>")
            {
                $IsList = $true
                $open = $Type[$i].LastIndexOf('<') + 1
                $close = $Type[$i].IndexOf('>')
                $TrueType = $Type[$i].Substring($open, $close - $open)
            }elseif($Type[$i] -cmatch ".*\[\]")
            {
                $IsList = $true
                $TrueType = $Type[$i].Substring(0, $Type[$i].Length - 2)
            }

            if((Test-Path "$($Variables["TargetRootPath"])\Domain\Entities\$($TrueType)\Models\$($TrueType).cs"))
            {
                if($IsList)
                {
                    $x += @"

        builder.HasMany($($EntityNameLower) => $($EntityNameLower).$($VarName[$i]))
            .WithOne()
"@
                }else
                {
                    $x += @"

        builder.HasOne($($EntityNameLower) => $($EntityNameLower).$($VarName[$i]))
            .WithMany()
            .HasForeignKey("$(ToSnake $VarName[$i])_id")
            .HasPrincipalKey(obj => obj.Id)
"@
                }
                $x += ";"

                $x += "`r`n"
            }
        }
        $File = $x + "`r`n        " + $File.Substring($FKStart + 1)
    }

    Write-Output $File.TrimEnd("`r", "`n") | Out-File -FilePath "$($Variables["TargetRootPath"])\Core\Entities\$($EntityName)\Mapping\$($EntityName)ClassMap.cs"

    return
}

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

public class $($EntityName)Repository($($Variables["DbContext"]) context)
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



$Content = Get-Content "$($Variables["TargetRootPath"])\Configuration\ConfigureRepositoriesExtension.cs"
$ContentOut = ""

foreach($line in $Content)
{
    $ContentOut += "$line`n"
    if($line.Trim() -eq "//Repositories")
    {
        $ContentOut += @"
        services.AddScoped<BaseRepository<$($EntityName)>, $($EntityName)Repository>();
        services.AddScoped<I$($EntityName)Repository, $($EntityName)Repository>();

"@
    }
}

Write-Output $ContentOut.TrimEnd("`r", "`n") | Out-File -FilePath "$($Variables["TargetRootPath"])\Configuration\ConfigureRepositoriesExtension.cs"



$Content = Get-Content "$($Variables["TargetRootPath"])\Configuration\ConfigureServicesExtension.cs"
$ContentOut = ""

foreach($line in $Content)
{
    $ContentOut += "$line`n"
    if($line.Trim() -eq "//Services")
    {
        $ContentOut += @"
        services.AddScoped<BaseService<$($EntityName)>, $($EntityName)Service>();
        services.AddScoped<I$($EntityName)Service, $($EntityName)Service>();

"@
    }
}

Write-Output $ContentOut.TrimEnd("`r", "`n") | Out-File -FilePath "$($Variables["TargetRootPath"])\Configuration\ConfigureServicesExtension.cs"