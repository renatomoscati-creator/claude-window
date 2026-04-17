cask "claude-window" do
  version "0.1.0"
  # Update sha256 after building and publishing the signed DMG:
  #   shasum -a 256 ClaudeWindow-0.1.0.dmg
  sha256 :no_check

  url "https://github.com/renatomoscati-creator/claude-window/releases/download/v#{version}/ClaudeWindow-#{version}.dmg"
  name "Claude Window"
  desc "Menu-bar companion for Claude power users — real-time service health and session capacity"
  homepage "https://github.com/renatomoscati-creator/claude-window"

  depends_on macos: ">= :ventura"

  app "ClaudeWindow.app"

  zap trash: [
    "~/Library/Application Support/ClaudeWindow",
    "~/Library/Preferences/com.renatomoscati.ClaudeWindow.plist",
    "~/Library/Caches/com.renatomoscati.ClaudeWindow",
  ]
end
