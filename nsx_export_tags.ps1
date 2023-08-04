$vcenter = Read-Host -Prompt "Enter vCenter FQDN/IP"

$vccred = Get-Credential -Message "vCenter Credentials"

$nsxmanager = Read-Host -Prompt "Enter NSX Manager FQDN/IP"

$nsxcred = Get-Credential -Message "NSX Manager Credentials"

$posturl = https://$nsxmanager/api/v1/fabric/virtual-machines?action=update_tags

$categories = @("Tier", "Environment", "Application", "Region", "Service")

 
# Connect to vCenter and fetch virtual machine info. Adjust this query to fetch a subset of virtual machine info.

Connect-VIServer -Server $vcenter -Credential $vccred

 

$vms = Get-VM

 

# Iterate over virtual machines

foreach ($vm in $vms) {

    # Get tags for virtual machine

    $tags = Get-TagAssignment -Entity $vm

 

    # Filter tags by category and format output

    $output = @{}

    $has_tags = $false

    foreach ($category in $categories) {

        $category_tags = $tags | Where-Object {$_.Tag.Category.Name -eq $category}

        $tag_names = $category_tags | ForEach-Object {$_.Tag.Name}

        if ($tag_names) {

            $has_tags = $true

            $output[$category] = $tag_names -join ", "

        }

    }

 

    # Display name and tags of virtual machine if it has any tags

    if ($has_tags) {

        Write-Host "Name: $($vm.Name)  InstanceUuid: $($vm.ExtensionData.Config.InstanceUuid)"

        foreach ($category in $categories) {

            if ($output.ContainsKey($category)) {

                Write-Host "${category}: $($output[$category])"

            }

        }

 

        # Construct JSON payload for NSX Manager API request

        $payload = @{

            external_id = $vm.ExtensionData.Config.InstanceUuid

            tags = @(

                foreach ($category in $categories) {

                    if ($output.ContainsKey($category)) {

                        $output[$category] | ForEach-Object {

                            @{

                                scope = $_

                                tag = $category

                            }

                        }

                    }

                }

            )

        } | ConvertTo-Json

 

        # Send HTTP PUT request to update NSX tags for virtual machine

        Invoke-RestMethod -Uri $posturl -Authentication Basic -Credential $nsxcred -Method POST -Body $payload -ContentType "application/json" -SkipCertificateCheck

 

        Write-Host "NSX tags updated for virtual machine $($vm.Name)"

        Write-Host

    }

}