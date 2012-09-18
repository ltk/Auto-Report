# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :report do
    client "MyString"
    title "MyString"
    analytics_key "MyString"
  end
end
