#!/bin/bash
set -euo pipefail

provider="$1"
name="$2"
path="$3"

# see https://developer.hashicorp.com/vagrant/docs/boxes/format#box-metadata
# see https://developer.hashicorp.com/vagrant/docs/boxes/format#box-file
# see https://github.com/hashicorp/packer-plugin-vagrant/blob/v1.0.3/post-processor/vagrant/libvirt.go#L100-L105
# see https://github.com/vagrant-libvirt/vagrant-libvirt/blob/0.11.2/spec/unit/action/handle_box_image_spec.rb#L96-L125
# see https://github.com/vagrant-libvirt/vagrant-libvirt/blob/0.11.2/lib/vagrant-libvirt/action/handle_box_image.rb
# see https://github.com/vagrant-libvirt/vagrant-libvirt/blob/0.11.2/docs/boxes.markdown
cat >"$path.json" <<EOF
{
  "name": "$name",
  "versions": [
    {
      "version": "0.0.0",
      "providers": [
        {
          "name": "$provider",
          "url": "$path"
        }
      ]
    }
  ]
}
EOF
cat <<EOF

Add the Vagrant Box with:

vagrant box add -f $name $path.json
EOF
