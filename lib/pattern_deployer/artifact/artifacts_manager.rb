#
# Copyright 2013 Marin Litoiu, Hongbin Lu, Mark Shtern, Bradlley Simmons, Mike
# Smit
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
require 'pattern_deployer/artifact/artifact'
require 'pattern_deployer/cloud'

module PatternDeployer
  module Artifact
    class ArtifactsManager
      include ArtifactType

      attr_reader :topology

      def initialize(topology, controller)
        @topology = topology
        @context = controller
        @artifacts = Array.new
      end

      def add_artifacts(artifact_records, artifact_type)
        artifact_records.each do |record|
          artifact = Artifact.new(record, artifact_type, @context)
          unless artifact_added?(artifact)
            @artifacts << artifact
          end
        end
      end

      def find_ec2_credential
        find_credential(Cloud::EC2)
      end

      def find_openstack_credential
        find_credential(Cloud::OPENSTACK)
      end

      def find_credential_by_id(id)
        @artifacts.find do |artifact|
          artifact.type == CREDENTIAL && artifact.get_id == id
        end
      end

      def find_credential_by_name(credential_name, cloud)
        credentials = @artifacts.select do |artifact|
          artifact.type == CREDENTIAL && artifact.credential_id == credential_name && cloud.casecmp(artifact.for_cloud) == 0
        end
        credential = select_one(credentials)
        credential
      end

      def find_keypair_id(cloud)
        keypairs = @artifacts.select do |artifact|
          artifact.type == KEY_PAIR && cloud.casecmp(artifact.for_cloud) == 0
        end
        keypair = select_one(keypairs)
        keypair && keypair.key_pair_id
      end

      def find_file_by_id(id)
        @artifacts.find{ |art| is_file?(art) && art.get_id == id }
      end

      def find_identity_file(key_pair_id)
        id_files = @artifacts.select do |artifact|
          artifact.type == KEY_PAIR && artifact.key_pair_id == key_pair_id
        end
        id_file = select_one(id_files)
        id_file
      end

      def find_file_by_name(file_name)
        files = @artifacts.select do |artifact|
          is_file?(artifact) && artifact.file_name == file_name
        end
        file = select_one(files)
        file
      end

      def each(&block)
        @artifacts.each(&block)
      end

      protected

      def artifact_added?(artifact)
        @artifacts.any? do |art|
          artifact.type == art.type && artifact.get_id == art.get_id
        end
      end

      def find_credential(cloud)
        credentials = @artifacts.select do |artifact|
          artifact.type == CREDENTIAL && cloud.casecmp(artifact.for_cloud) == 0
        end
        credential = select_one(credentials)
        credential
      end

      def select_one(artifacts)
        arifact = artifacts.find{ |art| art.owner.id == self.topology.owner.id && art.readable_by_me? }
        arifact = artifacts.find{ |art| art.owned_by_me? } if arifact.nil?
        arifact = artifacts.find{ |art| art.readable_by_me? } if arifact.nil?
        arifact
      end

      def is_file?(artifact)
        all_types = FileType.constants.map{ |c| FileType.const_get(c) }
        all_types.include?(artifact.type)
      end

    end
  end
end