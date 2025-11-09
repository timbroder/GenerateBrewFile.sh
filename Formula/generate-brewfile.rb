class GenerateBrewfile < Formula
  desc "Generate a comprehensive Brewfile with Homebrew, MAS, and .app metadata"
  homepage "https://github.com/timbroder/GenerateBrewFile.sh"
  url "https://github.com/timbroder/GenerateBrewFile.sh/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "44dbe3327dbe45c17940109eeaff0fc9fb2619984e45f4e76a8403ea9b393b98"
  license "MIT"
  head "https://github.com/timbroder/GenerateBrewFile.sh.git", branch: "main"

  def install
    bin.install "GenerateBrewFile.sh" => "generate-brewfile"
  end

  test do
    help_output = shell_output("#{bin}/generate-brewfile --help")
    assert_match "Usage: GenerateBrewFile.sh", help_output

    version_output = shell_output("#{bin}/generate-brewfile --version")
    assert_match version.to_s, version_output
  end
end
