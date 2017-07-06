using System;

namespace Saritasa.Git.GitFlowStatus
{
    class BranchInfo
    {
        public string Name { get; set; }
        public bool Merged { get; set; }
        public DateTime LastCommitDate { get; set; }
        public string Author { get; set; }
        public int ExclusiveCommits { get; set; }
    }
}
