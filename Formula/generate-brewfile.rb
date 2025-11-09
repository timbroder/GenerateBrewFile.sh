class GenerateBrewfile < Formula
  desc "Generate a comprehensive Brewfile with Homebrew, MAS, and .app metadata"
  homepage "https://github.com/timbroder/GenerateBrewFile.sh"
  url "https://raw.githubusercontent.com/timbroder/GenerateBrewFile.sh/main/GenerateBrewFile.sh", using: :nounzip
  version "0.1.1"
  sha256 "30dde631efbaaff5ddaf048ec5dddfa0fa43aa78be945119f7c8d7e6187af90e"
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
