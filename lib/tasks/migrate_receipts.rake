namespace :receipts do
  desc "Migrate receipt images from DB to ActiveStorage (R2)"
  task migrate_to_r2: :environment do
    Receipt.where.not(image_data: nil).find_each do |receipt|
      next if receipt.image.attached?
      
      puts "Migrating receipt #{receipt.id}..."
      
      begin
        io = StringIO.new(receipt.image_data)
        ext = receipt.image_content_type&.split("/")&.last || "jpg"
        filename = "receipt_#{receipt.id}_#{Time.current.to_i}.#{ext}"
        
        receipt.image.attach(
          io: io,
          filename: filename,
          content_type: receipt.image_content_type || "image/jpeg"
        )
        puts "Success: receipt #{receipt.id}"
      rescue => e
        puts "Error on receipt #{receipt.id}: #{e.message}"
      end
    end
    
    puts "Migration complete!"
  end
end
