export def jj-cheatsheet [] {
  {
    command: "jj"
    aliases: ["jj", "jujutsu"]
    title: "JJ (Jujutsu)"
    description: "Git -> JJ quick reference"
    rows: [
      {git: "git status", jj: "jj st"}
      {git: "git log --graph", jj: "jj log"}
      {git: "git diff", jj: "jj diff"}
      {git: "git commit -m \"msg\"", jj: "jj commit -m \"msg\""}
      {git: "git checkout <rev/branch>", jj: "jj edit <revset>"}
      {git: "git branch <name>", jj: "jj bookmark create <name>"}
      {git: "git pull / git fetch", jj: "jj git fetch"}
      {git: "git push origin <branch>", jj: "jj git push --bookmark <branch>"}
      {git: "(no easy equivalent)", jj: "jj undo"}
    ]
  }
}
