require "test_helper"

class AiImportTest < ActionDispatch::IntegrationTest
  test "analyze returns JSON with schedule" do
    user = users(:one) # Assuming fixture exists, or we mock it
    # If no users fixture, we can create one:
    # user = User.create!(email: "test@example.com", password: "password", name: "Test User")

    # Bypass Devise authentication
    post user_session_path, params: { user: { email: user.email, password: 'password' } }

    # Setup the file
    file1 = fixture_file_upload("/Users/jarvis/.gemini/antigravity/brain/ac78a756-aa49-4f0e-a421-a572dc52b288/media__1773407716175.jpg", "image/jpeg")
    
    # We will simulate current_user being present by mocking or just creating a valid user and signing in.
    # To keep things simple and ensure it works out of the box in the test environment, we'll just sign_in the user.
    # Actually, integration test for Devise:
    post user_session_path, params: { "user" => { "email" => user.email, "password" => 'password' } }
    
    # Post the request
    post "/ai_imports/analyze", params: { files: [file1] }, headers: { "Accept" => "application/json" }
    
    puts "\n--- RESPONSE STATUS ---"
    puts response.code
    puts "\n--- RESPONSE BODY ---"
    puts response.body[0..800]
  end
end
