# frozen_string_literal: true
# Power Tools Nautas edition glue: behaviour our forum needs on top of upstream,
# kept in one file so upstream merges rarely touch it.

after_initialize do
  # Mod whispers are regular posts with an audience. A core whisper flag
  # carried over by the composer (replying to a core whisper, e.g. inside a
  # category-lockdown topic) would hide the post from its non-staff targets,
  # so a post that became a mod whisper is always a regular post.
  module ::DiscourseModCategories::NautasWhisperPostType
    def prepare_new_post!(post, opts)
      result = super
      if post.custom_fields.key?(::DiscourseModCategories::POST_WHISPER_TARGETS_FIELD) &&
           post.post_type == ::Post.types[:whisper]
        post.post_type = ::Post.types[:regular]
      end
      result
    end
  end
  ::DiscourseModCategories::Whisper.singleton_class.prepend(
    ::DiscourseModCategories::NautasWhisperPostType,
  )

  # discourse-category-lockdown turns every reply in a "keep replies private"
  # category into a core whisper in before_create_tasks. The audience field
  # above is set earlier (PostCreator#setup_post), so lockdown can leave mod
  # whispers alone.
  if defined?(::CategoryLockdown) && ::CategoryLockdown.respond_to?(:whisper_reply?)
    module ::DiscourseModCategories::LockdownWhisperReplyPatch
      def whisper_reply?(post)
        if post.custom_fields.key?(::DiscourseModCategories::POST_WHISPER_TARGETS_FIELD)
          return false
        end
        super
      end
    end
    ::CategoryLockdown.singleton_class.prepend(::DiscourseModCategories::LockdownWhisperReplyPatch)
  end
end
