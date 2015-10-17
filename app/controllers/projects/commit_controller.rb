# Controller for a specific Commit
#
# Not to be confused with CommitsController, plural.
class Projects::CommitController < Projects::ApplicationController
  # Authorize
  before_action :require_non_empty_project
  before_action :authorize_download_code!
  before_action :commit
  before_action :define_show_vars, only: [:show, :ci]
  before_action :authorize_manage_builds!, only: [:cancel_builds, :retry_builds]

  def show
    return git_not_found! unless @commit

    @line_notes = commit.notes.inline
    @note = @project.build_commit_note(commit)
    @notes = commit.notes.not_inline.fresh
    @noteable = @commit
    @comments_allowed = @reply_allowed = true
    @comments_target  = {
      noteable_type: 'Commit',
      commit_id: @commit.id
    }

    respond_to do |format|
      format.html
      format.diff  { render text: @commit.to_diff }
      format.patch { render text: @commit.to_patch }
    end
  end

  def ci
    @ci_project = @project.gitlab_ci_project
  end

  def cancel_builds
    @ci_commit = @project.ci_commit(@commit.sha)
    @ci_commit.builds.running_or_pending.each(&:cancel)

    redirect_to ci_namespace_project_commit_path(project.namespace, project, commit.sha)
  end

  def retry_builds
    @ci_commit = @project.ci_commit(@commit.sha)
    @ci_commit.builds.latest.failed.each do |build|
      if build.retryable?
        Ci::Build.retry(build)
      end
    end

    redirect_to ci_namespace_project_commit_path(project.namespace, project, commit.sha)
  end

  def branches
    @branches = @project.repository.branch_names_contains(commit.id)
    @tags = @project.repository.tag_names_contains(commit.id)
    render layout: false
  end

  private

  def commit
    @commit ||= @project.commit(params[:id])
  end

  def define_show_vars
    @diffs = commit.diffs
    @notes_count = commit.notes.count
    
    @ci_commit = project.ci_commit(commit.sha)
    @builds = ci_commit.builds if ci_commit
  end

  def authorize_manage_builds!
    unless can?(current_user, :manage_builds, project)
      return page_404
    end
  end
end
