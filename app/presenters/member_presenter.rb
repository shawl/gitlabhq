class MemberPresenter < Gitlab::View::Presenter::Delegated
  include Gitlab::Allowable

  presents :member

  def can_resend_invite?
    invite? &&
      can?(current_user, admin_member_permission, source)
  end

  def can_update?
    can?(current_user, update_member_permission, member)
  end

  def cannot_update?
    !can_update?
  end

  def can_remove?
    can?(current_user, destroy_member_permission, member)
  end

  def can_approve?
    request? && can_update?
  end

  private

  def admin_member_permission
    raise NotImplementedError
  end

  def update_member_permission
    raise NotImplementedError
  end

  def destroy_member_permission
    raise NotImplementedError
  end
end
