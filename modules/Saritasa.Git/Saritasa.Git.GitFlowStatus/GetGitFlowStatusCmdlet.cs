using System;
using System.Linq;
using System.Management.Automation;
using System.Text.RegularExpressions;
using LibGit2Sharp;

namespace Saritasa.Git.GitFlowStatus
{
    public enum BranchType
    {
        // ReSharper disable once InconsistentNaming
        hotfix,
        // ReSharper disable once InconsistentNaming
        release,
        // ReSharper disable once InconsistentNaming
        feature
    }

    /// <summary>
    /// Powershell cmdlet which shows gitflow statistic
    /// Pipeline usage:
    /// $params = New-Object psobject -property @{BranchType = 'feature'; Path = 'C:\somepath'}
    /// $params| Get-GitFlowStatus
    /// </summary>
    [Cmdlet(VerbsCommon.Get, "GitFlowStatus")]
    [OutputType(typeof(BranchInfo))]
    public class GetGitFlowStatusCmdlet : Cmdlet, IDisposable
    {
        [Parameter(
             Mandatory = false,
             HelpMessage = "Path to git repository",
             ValueFromPipelineByPropertyName = true)]
        [Alias("p")]
        [ValidateNotNullOrEmpty]
        public string Path { get; set; }

        [Parameter(
            Mandatory = true,
            HelpMessage = "Specify branch type",
            ValueFromPipeline = true,
            ValueFromPipelineByPropertyName = true)]
        [Alias("b")]
        [ValidateNotNullOrEmpty]
        public BranchType BranchType { get; set; }

        [Parameter (
            Mandatory = false,
            HelpMessage = "Show branches with last commit made later than N days",
            ValueFromPipelineByPropertyName = true)]
        [ValidateNotNullOrEmpty]
        public int OlderThanDays{ get; set; }

        private Repository repo;

        private Branch developHead;

        /// <summary>
        /// 
        /// </summary>
        protected override void ProcessRecord()
        {
            base.ProcessRecord();

            if (!Repository.IsValid(Path))
            {
                throw new Exception("It is not valid git repo");
            }

            repo = new Repository(Path);

            // ASSERTION (repo has origin/develop branch and BranchType considered as merged if it is available from origin/develop)
            var develop = repo.Branches.Where(x => x.IsRemote && x.FriendlyName == "origin/develop").ToList();
            if (develop.Count != 1)
            {
                throw new Exception("Can't find origin/develop branch");
            }
            developHead = develop[0];

            // Find all remote branches which match pattern
            var branchTypePattern = new Regex($"\\/{BranchType}\\/(.+)");
            var requiredBranches = repo.Branches.Where(x => x.IsRemote && branchTypePattern.IsMatch(x.FriendlyName));

            // Apply OlderThanDays filter
            if (OlderThanDays > 0)
            {
                var timeInPast = DateTime.Now.AddDays(-OlderThanDays);
                requiredBranches = requiredBranches.Where(x => x.Tip.Committer.When.DateTime < timeInPast);
            }

            foreach (var branch in requiredBranches)
            {
                ProcessBranch(branch);
            }
        }

        /// <summary>
        /// Handles given branch, calculates BranchInfo object
        /// </summary>
        /// <param name="branch"></param>
        private void ProcessBranch(Branch branch)
        {

            var mergeBase = repo.ObjectDatabase.FindMergeBase(developHead.Tip, branch.Tip);
            var ret = new BranchInfo
            {
                Name = branch.FriendlyName,
                LastCommitDate = branch.Tip.Committer.When.DateTime,
                Merged = mergeBase == branch.Tip // Merge base for merged branches == to this branches
            };

            if (!ret.Merged)
            {
                // Leave only 'branch' commits. Since branch is not merged, merge base is pointed to branch parent commit
                var branchCommits = repo.Commits.QueryBy(
                   new CommitFilter
                   {
                       IncludeReachableFrom = branch.Tip,
                       ExcludeReachableFrom = mergeBase
                   });
                ret.Author = GetMostFrequentContributor(branchCommits).ToString();
                ret.ExclusiveCommits = branchCommits.Count();
            }
            else
            {
                // Merge commit has two parents
                var mergeCommit = developHead.Commits.First(x => x.Parents.Contains(branch.Tip));
                if (mergeCommit.Parents.Count() == 1)
                {
                    // There is no merge commit, this branch possible was rebased or fastforwarded.
                    // i.e. branch pointer points to usual commit in develop.
                    ret.Author = branch.Tip.Committer.ToString();
                    ret.ExclusiveCommits = 0;
                }
                else
                {
                    // Find commit before merge commit. current branch must be inaccessible from this commit. Use it in filtering
                    var oneCommitBeforeMerge = mergeCommit.Parents.First(x => x != branch.Tip);
                    var branchCommits = repo.Commits.QueryBy(
                        new CommitFilter
                        {
                            IncludeReachableFrom = branch.Tip,
                            ExcludeReachableFrom = oneCommitBeforeMerge
                        });
                    ret.Author = GetMostFrequentContributor(branchCommits).ToString();
                    ret.ExclusiveCommits = branchCommits.Count();
                }
            }
            WriteObject(ret);
        }

        /// <summary>
        /// Calculate most frequent contributor for list of commits.
        /// </summary>
        /// <param name="commits"></param>
        /// <returns></returns>
        private static LibGit2Sharp.Signature GetMostFrequentContributor(ICommitLog commits)
        {
            return commits.GroupBy(x => x.Author)
                .Select(x => new {Author = x.Key, CommitsCount = x.Count()})
                .OrderBy(x => x.CommitsCount)
                .First().Author;
        }

        /// <summary>
        /// Fortunately IDisposable is handled by caller. In case of exceptions it knows that Cmdlet must be Disposed.
        /// </summary>
        public void Dispose()
        {
            repo?.Dispose();
        }
    }
}
