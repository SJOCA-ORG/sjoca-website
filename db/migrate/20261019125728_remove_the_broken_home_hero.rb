# A photo row containing the eight bytes "NEWBYTES" -- test data that leaked
# into a database on 16 October -- and five pages pointed at it, including the
# home page of the PUBLISHED revision. The live site was serving an 8-byte PNG
# as its hero image.
#
# Nothing caught it because nothing checked: a Photo needed a name, a type and
# some bytes, and "NEWBYTES" is some bytes. The validation added alongside this
# closes that.
class RemoveTheBrokenHomeHero < ActiveRecord::Migration[8.1]
  def up
    broken = Photo.all.reject { |p| Admin::ImageTools.identify(p.data) }
    return say("no broken photographs", true) if broken.empty?

    broken.each do |photo|
      replacement = Photo.where(human_name: photo.human_name)
                         .where.not(id: photo.id)
                         .max_by(&:version)

      if replacement.nil?
        say "#{photo.human_name} v#{photo.version} is not an image and has no other version; left alone", true
        next
      end

      blocks = Block.where(asset_name: photo.human_name, asset_version: photo.version)
                    .update_all(asset_version: replacement.version)
      pages  = Page.where(hero_asset_name: photo.human_name, hero_asset_version: photo.version)
                   .update_all(hero_asset_version: replacement.version)

      say "#{photo.human_name} v#{photo.version} (#{photo.byte_size} bytes): " \
          "#{blocks + pages} references moved to v#{replacement.version}, row removed", true
      photo.destroy
    end
  end

  def down
    # It was never a photograph.
  end
end
