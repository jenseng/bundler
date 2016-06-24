# frozen_string_literal: true
require "spec_helper"

describe Bundler::SourceList do
  before do
    allow(Bundler).to receive(:root) { Pathname.new "./tmp/bundled_app" }
  end

  subject(:source_list) { Bundler::SourceList.new }

  describe "adding sources" do
    before do
      source_list.add_path_source("path" => "/existing/path/to/gem")
      source_list.add_git_source("uri" => "git://existing-git.org/path.git")
      source_list.add_rubygems_source("remotes" => ["https://existing-rubygems.org"])
    end

    describe "#add_path_source" do
      before do
        @duplicate = source_list.add_path_source("path" => "/path/to/gem")
        @new_source = source_list.add_path_source("path" => "/path/to/gem")
      end

      it "returns the new path source" do
        expect(@new_source).to be_instance_of(Bundler::Source::Path)
      end

      it "passes the provided options to the new source" do
        expect(@new_source.options).to eq("path" => "/path/to/gem")
      end

      it "adds the source to the beginning of path_sources" do
        expect(source_list.path_sources.first).to equal(@new_source)
      end

      it "removes existing duplicates" do
        expect(source_list.path_sources).not_to include equal(@duplicate)
      end
    end

    describe "#add_git_source" do
      before do
        @duplicate = source_list.add_git_source("uri" => "git://host/path.git")
        @new_source = source_list.add_git_source("uri" => "git://host/path.git")
      end

      it "returns the new git source" do
        expect(@new_source).to be_instance_of(Bundler::Source::Git)
      end

      it "passes the provided options to the new source" do
        expect(@new_source.options).to eq("uri" => "git://host/path.git")
      end

      it "adds the source to the beginning of git_sources" do
        expect(source_list.git_sources.first).to equal(@new_source)
      end

      it "removes existing duplicates" do
        @duplicate = source_list.add_git_source("uri" => "git://host/path.git")
        @new_source = source_list.add_git_source("uri" => "git://host/path.git")
        expect(source_list.git_sources).not_to include equal(@duplicate)
      end

      context "with the git: protocol" do
        let(:msg) do
          "The git source `git://existing-git.org/path.git` " \
          "uses the `git` protocol, which transmits data without encryption. " \
          "Disable this warning with `bundle config git.allow_insecure true`, " \
          "or switch to the `https` protocol to keep your data secure."
        end

        it "warns about git protocols" do
          expect(Bundler.ui).to receive(:warn).with(msg)
          source_list.add_git_source("uri" => "git://existing-git.org/path.git")
        end

        it "ignores git protocols on request" do
          Bundler.settings["git.allow_insecure"] = true
          expect(Bundler.ui).to_not receive(:warn).with(msg)
          source_list.add_git_source("uri" => "git://existing-git.org/path.git")
        end
      end
    end

    describe "#add_rubygems_source" do
      before do
        @duplicate = source_list.add_rubygems_source("remotes" => ["https://rubygems.org/"])
        @new_source = source_list.add_rubygems_source("remotes" => ["https://rubygems.org/"])
      end

      it "returns the new rubygems source" do
        expect(@new_source).to be_instance_of(Bundler::Source::Rubygems)
      end

      it "passes the provided options to the new source" do
        expect(@new_source.options).to eq("remotes" => ["https://rubygems.org/"])
      end

      it "adds the source to the beginning of rubygems_sources" do
        expect(source_list.rubygems_sources.first).to equal(@new_source)
      end

      it "removes duplicates" do
        expect(source_list.rubygems_sources).not_to include equal(@duplicate)
      end
    end

    describe "#global_rubygems_remote=" do
      before do
        source_list.global_rubygems_remote = "https://rubygems.org/"
        @returned_source = source_list.global_rubygems_source
      end

      it "returns the aggregate rubygems source" do
        expect(@returned_source).to be_instance_of(Bundler::Source::Rubygems)
        expect(source_list.rubygems_sources).to end_with @returned_source
      end

      it "resets the global source" do
        source_list.global_rubygems_remote = "https://othersource.org"
        new_global = source_list.global_rubygems_source
        expect(new_global.remotes.first).to eq(URI("https://othersource.org/"))
        expect(source_list.global_rubygems_source).to eq(new_global)
        expect(source_list.rubygems_sources).not_to include(@returned_source)
      end
    end
  end

  describe "#all_sources" do
    it "includes the aggregate rubygems source when rubygems sources have been added" do
      git = source_list.add_git_source("uri" => "git://host/path.git")
      rubygems = source_list.add_rubygems_source("remotes" => ["https://rubygems.org"])
      path = source_list.add_path_source("path" => "/path/to/gem")

      expect(source_list.all_sources).to include(git, rubygems, path)
    end

    it "includes the aggregate rubygems source when no rubygems sources have been added" do
      source_list.add_git_source("uri" => "git://host/path.git")
      source_list.add_path_source("path" => "/path/to/gem")

      expect(source_list.all_sources).to include source_list.default_source
    end

    it "returns sources of the same type in the reverse order that they were added" do
      source_list.add_git_source("uri" => "git://third-git.org/path.git")
      source_list.add_rubygems_source("remotes" => ["https://fifth-rubygems.org"])
      source_list.add_path_source("path" => "/third/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://fourth-rubygems.org"])
      source_list.add_path_source("path" => "/second/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://third-rubygems.org"])
      source_list.add_git_source("uri" => "git://second-git.org/path.git")
      source_list.add_rubygems_source("remotes" => ["https://second-rubygems.org"])
      source_list.add_path_source("path" => "/first/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://first-rubygems.org"])
      source_list.add_git_source("uri" => "git://first-git.org/path.git")

      expect(source_list.all_sources).to eq [
        Bundler::Source::Path.new("path" => "/first/path/to/gem"),
        Bundler::Source::Path.new("path" => "/second/path/to/gem"),
        Bundler::Source::Path.new("path" => "/third/path/to/gem"),
        Bundler::Source::Git.new("uri" => "git://first-git.org/path.git"),
        Bundler::Source::Git.new("uri" => "git://second-git.org/path.git"),
        Bundler::Source::Git.new("uri" => "git://third-git.org/path.git"),
        Bundler::Source::Rubygems.new("remotes" => ["https://first-rubygems.org"]),
        Bundler::Source::Rubygems.new("remotes" => ["https://second-rubygems.org"]),
        Bundler::Source::Rubygems.new("remotes" => ["https://third-rubygems.org"]),
        Bundler::Source::Rubygems.new("remotes" => ["https://fourth-rubygems.org"]),
        Bundler::Source::Rubygems.new("remotes" => ["https://fifth-rubygems.org"]),
        source_list.default_source,
      ]
    end
  end

  describe "#path_sources" do
    it "returns an empty array when no path sources have been added" do
      source_list.add_rubygems_source("remotes" => "https://rubygems.org")
      source_list.add_git_source("uri" => "git://host/path.git")
      expect(source_list.path_sources).to be_empty
    end

    it "returns path sources in the reverse order that they were added" do
      source_list.add_git_source("uri" => "git://third-git.org/path.git")
      source_list.add_rubygems_source("remotes" => "https://fifth-rubygems.org")
      source_list.add_path_source("path" => "/third/path/to/gem")
      source_list.add_rubygems_source("remotes" => "https://fourth-rubygems.org")
      source_list.add_path_source("path" => "/second/path/to/gem")
      source_list.add_rubygems_source("remotes" => "https://third-rubygems.org")
      source_list.add_git_source("uri" => "git://second-git.org/path.git")
      source_list.add_rubygems_source("remotes" => "https://second-rubygems.org")
      source_list.add_path_source("path" => "/first/path/to/gem")
      source_list.add_rubygems_source("remotes" => "https://first-rubygems.org")
      source_list.add_git_source("uri" => "git://first-git.org/path.git")

      expect(source_list.path_sources).to eq [
        Bundler::Source::Path.new("path" => "/first/path/to/gem"),
        Bundler::Source::Path.new("path" => "/second/path/to/gem"),
        Bundler::Source::Path.new("path" => "/third/path/to/gem"),
      ]
    end
  end

  describe "#git_sources" do
    it "returns an empty array when no git sources have been added" do
      source_list.add_rubygems_source("remotes" => "https://rubygems.org")
      source_list.add_path_source("path" => "/path/to/gem")

      expect(source_list.git_sources).to be_empty
    end

    it "returns git sources in the reverse order that they were added" do
      source_list.add_git_source("uri" => "git://third-git.org/path.git")
      source_list.add_rubygems_source("remotes" => "https://fifth-rubygems.org")
      source_list.add_path_source("path" => "/third/path/to/gem")
      source_list.add_rubygems_source("remotes" => "https://fourth-rubygems.org")
      source_list.add_path_source("path" => "/second/path/to/gem")
      source_list.add_rubygems_source("remotes" => "https://third-rubygems.org")
      source_list.add_git_source("uri" => "git://second-git.org/path.git")
      source_list.add_rubygems_source("remotes" => "https://second-rubygems.org")
      source_list.add_path_source("path" => "/first/path/to/gem")
      source_list.add_rubygems_source("remotes" => "https://first-rubygems.org")
      source_list.add_git_source("uri" => "git://first-git.org/path.git")

      expect(source_list.git_sources).to eq [
        Bundler::Source::Git.new("uri" => "git://first-git.org/path.git"),
        Bundler::Source::Git.new("uri" => "git://second-git.org/path.git"),
        Bundler::Source::Git.new("uri" => "git://third-git.org/path.git"),
      ]
    end
  end

  describe "#rubygems_sources" do
    it "includes the aggregate rubygems source when rubygems sources have been added" do
      source_list.add_git_source("uri" => "git://host/path.git")
      rg = source_list.add_rubygems_source("remotes" => ["https://rubygems.org"])
      source_list.add_path_source("path" => "/path/to/gem")

      expect(source_list.rubygems_sources).to end_with(rg, source_list.default_source)
    end

    it "returns only the aggregate rubygems source when no rubygems sources have been added" do
      source_list.add_git_source("uri" => "git://host/path.git")
      source_list.add_path_source("path" => "/path/to/gem")

      expect(source_list.rubygems_sources).to eq [source_list.default_source]
    end

    it "returns rubygems sources in the reverse order that they were added" do
      source_list.add_git_source("uri" => "git://third-git.org/path.git")
      source_list.add_rubygems_source("remotes" => ["https://fifth-rubygems.org"])
      source_list.add_path_source("path" => "/third/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://fourth-rubygems.org"])
      source_list.add_path_source("path" => "/second/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://third-rubygems.org"])
      source_list.add_git_source("uri" => "git://second-git.org/path.git")
      source_list.add_rubygems_source("remotes" => ["https://second-rubygems.org"])
      source_list.add_path_source("path" => "/first/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://first-rubygems.org"])
      source_list.add_git_source("uri" => "git://first-git.org/path.git")

      expect(source_list.rubygems_sources).to eq [
        Bundler::Source::Rubygems.new("remotes" => ["https://first-rubygems.org"]),
        Bundler::Source::Rubygems.new("remotes" => ["https://second-rubygems.org"]),
        Bundler::Source::Rubygems.new("remotes" => ["https://third-rubygems.org"]),
        Bundler::Source::Rubygems.new("remotes" => ["https://fourth-rubygems.org"]),
        Bundler::Source::Rubygems.new("remotes" => ["https://fifth-rubygems.org"]),
        source_list.default_source,
      ]
    end
  end

  describe "#get" do
    context "when it includes an equal source" do
      let(:rubygems_source) { Bundler::Source::Rubygems.new("remotes" => ["https://rubygems.org"]) }
      before { @equal_source = source_list.add_rubygems_source("remotes" => "https://rubygems.org") }

      it "returns the equal source" do
        expect(source_list.get(rubygems_source)).to be @equal_source
      end
    end

    context "when it does not include an equal source" do
      let(:path_source) { Bundler::Source::Path.new("path" => "/path/to/gem") }

      it "returns nil" do
        expect(source_list.get(path_source)).to be_nil
      end
    end
  end

  describe "#lock_sources" do
    it "combines the rubygems sources into a single instance, removing duplicate remotes from the end" do
      source_list.add_git_source("uri" => "git://third-git.org/path.git")
      source_list.add_rubygems_source("remotes" => ["https://duplicate-rubygems.org"])
      source_list.add_path_source("path" => "/third/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://third-rubygems.org"])
      source_list.add_path_source("path" => "/second/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://second-rubygems.org"])
      source_list.add_git_source("uri" => "git://second-git.org/path.git")
      source_list.add_rubygems_source("remotes" => ["https://first-rubygems.org"])
      source_list.add_path_source("path" => "/first/path/to/gem")
      source_list.add_rubygems_source("remotes" => ["https://duplicate-rubygems.org"])
      source_list.add_git_source("uri" => "git://first-git.org/path.git")

      expect(source_list.lock_sources).to eq [
        Bundler::Source::Rubygems.new,
        Bundler::Source::Rubygems.new("remotes" => "https://duplicate-rubygems.org"),
        Bundler::Source::Rubygems.new("remotes" => "https://first-rubygems.org"),
        Bundler::Source::Rubygems.new("remotes" => "https://second-rubygems.org"),
        Bundler::Source::Rubygems.new("remotes" => "https://third-rubygems.org"),
        Bundler::Source::Git.new("uri" => "git://first-git.org/path.git"),
        Bundler::Source::Git.new("uri" => "git://second-git.org/path.git"),
        Bundler::Source::Git.new("uri" => "git://third-git.org/path.git"),
        Bundler::Source::Path.new("path" => "/first/path/to/gem"),
        Bundler::Source::Path.new("path" => "/second/path/to/gem"),
        Bundler::Source::Path.new("path" => "/third/path/to/gem"),
      ]
    end
  end

  describe "replace_sources!" do
    let(:existing_locked_source) { Bundler::Source::Path.new("path" => "/existing/path") }
    let(:removed_locked_source)  { Bundler::Source::Path.new("path" => "/removed/path") }

    let(:locked_sources) { [existing_locked_source, removed_locked_source] }

    before do
      @existing_source = source_list.add_path_source("path" => "/existing/path")
      @new_source = source_list.add_path_source("path" => "/new/path")
      source_list.replace_sources!(locked_sources)
    end

    it "maintains the order and number of sources" do
      expect(source_list.path_sources).to eq [@new_source, @existing_source]
    end

    it "retains the same instance of the new source" do
      expect(source_list.path_sources[0]).to be @new_source
    end

    it "replaces the instance of the existing source" do
      expect(source_list.path_sources[1]).to be existing_locked_source
    end
  end

  describe "#cached!" do
    let(:rubygems_source) { source_list.add_rubygems_source("remotes" => "https://rubygems.org") }
    let(:git_source)      { source_list.add_git_source("uri" => "git://host/path.git") }
    let(:path_source)     { source_list.add_path_source("path" => "/path/to/gem") }

    it "calls #cached! on all the sources" do
      expect(rubygems_source).to receive(:cached!)
      expect(git_source).to receive(:cached!)
      expect(path_source).to receive(:cached!)
      source_list.cached!
    end
  end

  describe "#remote!" do
    let(:rubygems_source) { source_list.add_rubygems_source("remotes" => "https://rubygems.org") }
    let(:git_source)      { source_list.add_git_source("uri" => "git://host/path.git") }
    let(:path_source)     { source_list.add_path_source("path" => "/path/to/gem") }

    it "calls #remote! on all the sources" do
      expect(rubygems_source).to receive(:remote!)
      expect(git_source).to receive(:remote!)
      expect(path_source).to receive(:remote!)
      source_list.remote!
    end
  end
end
