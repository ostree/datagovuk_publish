require "rails_helper"

describe "dataset creation" do

  let(:land) { FactoryGirl.create(:organisation, name: 'land-registry', title: 'Land Registry') }
  let(:user) { FactoryGirl.create(:user, primary_organisation: land) }
  let(:dataset) { FactoryGirl.create(:dataset, organisation: land, creator: user, owner: user ) }

  context "when the user goes through entire flow" do

    before(:each) do
      user
      sign_in_user
    end

    it "navigates to new dataset form" do
      expect(page).to have_current_path("/tasks")
      click_link "Manage datasets"
      click_link "Create a dataset"
      expect(page).to have_current_path("/datasets/new")
      expect(page).to have_content("Create a dataset")
    end

    it "publishes a dataset" do
      visit "/datasets/new"

      # PAGE 1: New
      fill_in "dataset[title]", with: "my test dataset"
      fill_in "dataset[summary]", with: "my test dataset summary"
      fill_in "dataset[description]", with: "my test dataset description"
      click_button "Save and continue"

      expect(Dataset.where(title: "my test dataset").length).to eq(1)

      # PAGE 2: Licence
      choose option: "uk-ogl"
      click_button "Save and continue"

      expect(Dataset.last.licence).to eq("uk-ogl")

      # Page 3: Location
      fill_in "dataset[location1]", with: "Aviation House"
      fill_in "dataset[location2]", with: "London"
      fill_in "dataset[location3]", with: "England"
      click_button "Save and continue"

      expect(Dataset.last.location1).to eq("Aviation House")
      expect(Dataset.last.location2).to eq("London")
      expect(Dataset.last.location3).to eq("England")

      # Page 4: Frequency
      choose option: "never"
      click_button "Save and continue"

      expect(Dataset.last.frequency).to eq("never")

      # Page 5: Add Datafile
      fill_in 'link[url]', with: 'https://localhost'
      fill_in 'link[name]', with: 'my test datafile'
      click_button "Save and continue"

      expect(Dataset.last.links.length).to eq(1)
      expect(Dataset.last.links.last.url).to eq('https://localhost')
      expect(Dataset.last.links.last.name).to eq('my test datafile')

      # Files page
      expect(page).to have_content("Links to your data")
      expect(page).to have_content("my test datafile")
      click_link "Save and continue"

      # Page 6: Add Documents
      # TODO: fix new flow
      #fill_in 'doc[url]', with: 'https://localhost/doc'
      #fill_in 'doc[name]', with: 'my test doc'
      #click_button "Save and continue"

      #expect(Dataset.last.docs.length).to eq(1)
      #expect(Dataset.last.docs.last.url).to eq('https://localhost/doc')
      #expect(Dataset.last.docs.last.name).to eq('my test doc')

      # Documents page
      #expect(page).to have_content("Links to supporting documents")
      #expect(page).to have_content("my test doc")
      #click_link "Save and continue"

      # Page 9: Publish Page
      expect(Dataset.last.published).to be(false)
      expect(page).to have_content(Dataset.last.status)
      expect(page).to have_content(Dataset.last.organisation.title)
      expect(page).to have_content(Dataset.last.title)
      expect(page).to have_content(Dataset.last.summary)
      expect(page).to have_content(Dataset.last.description)
      expect(page).to have_content("Open Government Licence")
      expect(page).to have_content(Dataset.last.location1)
      expect(page).to have_content("One-off")
      expect(page).to have_content(Dataset.last.links.first.name)
      expect(page).to have_content(Dataset.last.links.last.name)

      click_button "Publish"

      expect(page).to have_content("Your dataset has been published")
      expect(Dataset.last.published).to be(true)

      # Ensure the dataset is indexed in Elastic
      client = Dataset.__elasticsearch__.client
      document = client.get({ index: Dataset.index_name, id: Dataset.last.id })
      expect(document["_source"]["name"]).to eq("my-test-dataset")
    end
  end

  context "when the user doesn't complete flow" do

    before(:each) do
      user
      sign_in_user
    end

    it "saves a draft" do
      visit "/datasets/new"
      fill_in "dataset[title]", with: "my test dataset"
      fill_in "dataset[summary]", with: "my test dataset summary"
      fill_in "dataset[description]", with: "my test dataset description"
      click_button "Save and continue"

      expect(Dataset.where(title: "my test dataset").length).to eq(1)
      expect(Dataset.find_by(title: "my test dataset").creator_id).to eq(user.id)
    end

    it 'displays drafts' do
      dataset
      click_link 'Manage datasets'
      expect(page).to have_content(dataset.title)
      visit '/datasets/dataset-title'
    end
  end
end

describe "starting a new draft with invalid inputs" do

  let(:land) { FactoryGirl.create(:organisation, name: 'land-registry', title: 'Land Registry') }
  let(:user) { FactoryGirl.create(:user, primary_organisation: land) }

  before(:each) do
    user
    sign_in_user
    visit "/datasets/new"
  end

  it "missing title" do
    fill_in "dataset[summary]", with: "my test dataset summary"
    click_button "Save and continue"
    expect(page).to have_content("There was a problem")
    expect(page).to have_content("Please enter a valid title", count: 2)
    page.should have_selector("div", :class => "form-group-error")
    expect(Dataset.where(title: "my test dataset").length).to eq(0)
    # recover
    fill_in "dataset[title]", with: "my test dataset"
    fill_in "dataset[summary]", with: "my test dataset summary"
    fill_in "dataset[description]", with: "my test dataset description"
    click_button "Save and continue"
    expect(page).to have_content("Choose a licence")
  end

  it "missing summary" do
    fill_in "dataset[title]", with: "my test dataset"
    click_button "Save and continue"
    expect(page).to have_content("There was a problem")
    expect(page).to have_content("Please provide a summary", count: 2)
    page.should have_selector("div", :class => "form-group-error")
    expect(Dataset.where(title: "my test dataset").length).to eq(0)
    # recover
    fill_in "dataset[title]", with: "my test dataset"
    fill_in "dataset[summary]", with: "my test dataset summary"
    fill_in "dataset[description]", with: "my test dataset description"
    click_button "Save and continue"
    expect(page).to have_content("Choose a licence")
  end

  it "missing both title and summary" do
    click_button "Save and continue"
    expect(page).to have_content("There was a problem")
    expect(page).to have_content("Please enter a valid title", count: 2)
    expect(page).to have_content("Please provide a summary", count: 2)
    expect(Dataset.where(title: "my test dataset").length).to eq(0)
    # recover
    fill_in "dataset[title]", with: "my test dataset"
    fill_in "dataset[summary]", with: "my test dataset summary"
    fill_in "dataset[description]", with: "my test dataset description"
    click_button "Save and continue"
    expect(page).to have_content("Choose a licence")
  end
end

describe "valid options for licence and area" do

  let(:land_registry) { FactoryGirl.create(:organisation, name: 'land-registry', title: 'Land Registry') }
  let(:user) { FactoryGirl.create(:user, primary_organisation: land_registry) }

  before(:each) do
    user
    sign_in_user
    visit "/datasets/new"
    fill_in "dataset[title]", with: "my test dataset"
    fill_in "dataset[summary]", with: "my test dataset summary"
    fill_in "dataset[description]", with: "my test dataset description"
    click_button "Save and continue"
  end

  context "when selecting license type" do
    it "OGL" do
      expect(page).to have_content("Choose a licence")
      choose option: "uk-ogl"
      click_button "Save and continue"
      expect(page).to have_content("Choose a geographical area")
    end

    it "missing a licence, continue anyway" do
      click_button "Save and continue"
      expect(page).to have_content("Choose a geographical area")
    end

    it "skips licence" do
      click_link "Skip this step"
      expect(page).to have_content("Choose a geographical area")
    end

    it "selected other licence but didn't specify" do
      choose option: "other"
      click_button "Save and continue"
      expect(page).to have_content("Please type the name of your licence", count: 2)
      fill_in "dataset[licence_other]", with: "MIT"
      click_button "Save and continue"
      expect(page).to have_content("Choose a geographical area")
    end
  end

  context "when selecting geographical area" do
    before(:each) do
      choose option: "uk-ogl"
      click_button "Save and continue"
    end

    it "allows entering a geographical area" do
      fill_in "dataset[location1]", with: "High Wycombe"
      click_button "Save and continue"
      expect(page).to have_content("How frequently is this dataset updated?")
    end

    it "allows not entering a geographical area" do
      click_button "Save and continue"
      expect(page).to have_content("How frequently is this dataset updated?")
    end
  end
end

describe "dataset frequency options" do

  let(:land) { FactoryGirl.create(:organisation, name: 'land-registry', title: 'Land Registry') }
  let(:user) { FactoryGirl.create(:user, primary_organisation: land) }
  let(:dataset) { FactoryGirl.create(:dataset, organisation: land, owner: user ) }

  before(:each) do
    user
    sign_in_user
    dataset
    visit "/datasets/dataset-title/frequency/new"
  end

  context "when Never and Daily" do

    it "selecting NEVER hides fields and dates" do
      choose option: 'never'
      click_button "Save and continue"

      expect(page).to_not have_content('Start Date')
      expect(page).to_not have_content('End Date')
      expect(page).to_not have_content('Year')

      fill_in 'link[url]', with: 'https://localhost/doc'
      fill_in 'link[name]', with: 'my test doc'
      click_button "Save and continue"

      expect(Dataset.last.datafiles.last.start_date).to be_nil
      expect(Dataset.last.datafiles.last.end_date).to be_nil
    end

    it "selecting DAILY hides fields and dates" do
      choose option: 'daily'
      click_button "Save and continue"

      expect(page).to_not have_content('Start Date')
      expect(page).to_not have_content('End Date')
      expect(page).to_not have_content('Year')

      fill_in 'link[url]', with: 'https://localhost/doc'
      fill_in 'link[name]', with: 'my test doc'
      click_button "Save and continue"

      expect(Dataset.last.datafiles.last.start_date).to be_nil
      expect(Dataset.last.datafiles.last.end_date).to be_nil
    end
  end

  context "when WEEKLY" do
    before(:each) do
      choose option: 'weekly'
      click_button "Save and continue"
      fill_in 'link[url]', with: 'https://localhost/doc'
      fill_in 'link[name]', with: 'my test doc'
    end

    it "shows start and end date fields and sets dates" do
      expect(page).to     have_content('Start Date')
      expect(page).to     have_content('End Date')

      # Start Date
      fill_in 'link[start_day]',   with: '1'
      fill_in 'link[start_month]', with: '1'
      fill_in 'link[start_year]',  with: '2020'

      # End Date
      fill_in 'link[end_day]',   with: '8'
      fill_in 'link[end_month]', with: '1'
      fill_in 'link[end_year]',  with: '2020'

      click_button "Save and continue"

      expect(Dataset.last.datafiles.last.start_date).to eq(Date.new(2020, 1, 1))
      expect(Dataset.last.datafiles.last.end_date).to eq(Date.new(2020, 1, 8))
    end

    it "displays errors when dates aren't entered" do

      click_button "Save and continue"

      expect(page).to have_content("There was a problem")
      expect(page).to have_content("Please enter a valid start day")
      expect(page).to have_content("Please enter a valid start month")
      expect(page).to have_content("Please enter a valid start year")
      expect(page).to have_content("Please enter a valid end day")
      expect(page).to have_content("Please enter a valid end month")
      expect(page).to have_content("Please enter a valid end year")
    end

    it "displays errors when dates aren't valid" do

      fill_in 'link[start_day]', with: '30'
      fill_in 'link[start_month]', with: '02'
      fill_in 'link[start_year]',  with: '2020'

      fill_in 'link[end_day]', with: '30'
      fill_in 'link[end_month]', with: '03'
      fill_in 'link[end_year]',  with: '2020'


      click_button "Save and continue"

      expect(page).to have_content("There was a problem")
      expect(page).to_not have_content("Please enter a valid day")
      expect(page).to_not have_content("Please enter a valid month")
      expect(page).to_not have_content("Please enter a valid year")
      expect(page).to have_content("Please enter a valid start date")
    end
  end

  context "when MONTHLY" do
    before(:each) do
      choose option: 'monthly'
      click_button "Save and continue"
      fill_in 'link[url]', with: 'https://localhost/doc'
      fill_in 'link[name]', with: 'my test doc'
    end

    it "shows start date field and sets dates" do
      expect(page).to_not have_content('Start Date')
      expect(page).to_not have_content('End Date')
      expect(page).to     have_content('Month')
      expect(page).to     have_content('Year')

      # Start Date
      fill_in 'link[start_month]', with: '1'
      fill_in 'link[start_year]',  with: '2020'

      click_button "Save and continue"

      expect(Dataset.last.datafiles.last.start_date).to eq(Date.new(2020, 1, 1))
      expect(Dataset.last.datafiles.last.end_date).to eq(Date.new(2020, 1).end_of_month)
    end

    it "displays errors when dates aren't entered" do

      click_button "Save and continue"

      expect(page).to have_content("There was a problem")
      expect(page).to have_content("Please enter a valid month")
      expect(page).to have_content("Please enter a valid year")
    end
  end

  context "when QUARTERLY" do
    before(:each) do
      choose option: 'quarterly'
      click_button "Save and continue"
    end

    def pick_quarter(quarter)
      expect(page).to_not have_content('Start Date')
      expect(page).to_not have_content('End Date')
      expect(page).to_not have_content('Month')
      expect(page).to     have_content('Year')
      expect(page).to     have_content('Quarter')
      fill_in 'link[url]', with: 'https://localhost/doc'
      fill_in 'link[name]', with: 'my test doc'
      choose option: quarter.to_s
      fill_in "link[start_year]", with: Date.today.year
      click_button "Save and continue"

    end

    it "calculates correct dates for Q1" do
      pick_quarter(1)
      expect(Dataset.last.datafiles.last.start_date).to eq(Date.new(Date.today.year, 4, 1))
      expect(Dataset.last.datafiles.last.end_date).to eq(Date.new(Date.today.year, 6).end_of_month)
    end

    it "calculates correct dates for Q2" do
      pick_quarter(2)
      expect(Dataset.last.datafiles.last.start_date).to eq(Date.new(Date.today.year, 7, 1))
      expect(Dataset.last.datafiles.last.end_date).to eq(Date.new(Date.today.year, 9).end_of_month)
    end

    it "calculates correct dates for Q3" do
      pick_quarter(3)
      expect(Dataset.last.datafiles.last.start_date).to eq(Date.new(Date.today.year, 10, 1))
      expect(Dataset.last.datafiles.last.end_date).to eq(Date.new(Date.today.year, 12).end_of_month)
    end

    it "calculates correct dates for Q4" do
      pick_quarter(4)
      expect(Dataset.last.datafiles.last.start_date).to eq(Date.new(Date.today.year, 1, 1) + 1.year)
      expect(Dataset.last.datafiles.last.end_date).to eq(Date.new(Date.today.year, 3).end_of_month + 1.year)
    end
  end

  context "when YEARLY" do

    def pick_year(year_type)
      choose option: year_type
      click_button "Save and continue"
      expect(page).to_not have_content('Start Date')
      expect(page).to_not have_content('End Date')
      expect(page).to_not have_content('Month')
      expect(page).to     have_content('Year')
      fill_in 'link[url]', with: 'https://localhost/doc'
      fill_in 'link[name]', with: 'my test doc'
      fill_in 'link[start_year]',  with: '2015'
      click_button "Save and continue"
    end

    it "shows year field and sets dates" do
      pick_year('annually')
      expect(Dataset.last.datafiles.last.start_date).to eq(Date.new(2015, 1, 1))
      expect(Dataset.last.datafiles.last.end_date).to eq(Date.new(2015, 12).end_of_month)
    end

    it "shows financial year and sets dates" do
      pick_year('financial-year')
      expect(Dataset.last.datafiles.last.start_date).to eq(Date.new(2015, 4, 1))
      expect(Dataset.last.datafiles.last.end_date).to eq(Date.new(2016, 3).end_of_month)
    end
  end
end

describe "passing the frequency page" do

  let(:land) { FactoryGirl.create(:organisation, name: 'land-registry', title: 'Land Registry') }
  let(:user) { FactoryGirl.create(:user, primary_organisation: land) }
  let(:dataset) { FactoryGirl.create(:dataset, organisation: land, owner: user, frequency: nil ) }

  before(:each) do
    user
    dataset
    sign_in_user
    visit 'datasets/dataset-title/frequency/new'
  end

  it "mandates entering a frequency" do
    click_button "Save and continue"
    expect(page).to have_content("Please indicate how often this dataset is updated", count: 2)
    choose option: "never"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
  end

  it "continues once user specifies a frequency" do
    choose option: "never"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
  end

  it "routes to the daily datafiles page and check for errors" do
    choose option: "daily"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
    expect(page).to_not have_content("Year")
    click_button "Save and continue"
    expect(page).to have_content("Please enter a valid URL", count: 2)
    expect(page).to have_content("Please enter a valid name", count: 2)
    fill_in "link[url]", with: "http://www.example.com/test.csv"
    fill_in "link[name]", with: "Test datafile"
    click_button "Save and continue"
    expect(page).to have_content("Links to your data")
  end

  it "routes to the one-off datafiles page" do
    choose option: "never"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
    expect(page).to_not have_content("Year")
  end

  it "routes to the weekly datafiles page and check for errors" do
    choose option: "weekly"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
    expect(page).to have_content("Start Date")
    expect(page).to have_content("End Date")
    fill_in "link[url]", with: "http://www.example.com/test.csv"
    fill_in "link[name]", with: "Test datafile"
    click_button "Save and continue"
    expect(page).to have_content("Please enter a valid start day", count: 2)
    expect(page).to have_content("Please enter a valid start month", count: 2)
    expect(page).to have_content("Please enter a valid start year", count: 2)
    expect(page).to have_content("Please enter a valid end day", count: 2)
    expect(page).to have_content("Please enter a valid end month", count: 2)
    expect(page).to have_content("Please enter a valid end year", count: 2)
    fill_in "link[start_day]", with: "234"
    fill_in "link[start_month]", with: "June"
    fill_in "link[start_year]", with: "234"
    fill_in "link[end_day]", with: "234"
    fill_in "link[end_month]", with: "234"
    fill_in "link[end_year]", with: "234"
    click_button "Save and continue"
    expect(page).to have_content("Please enter a valid start day", count: 2)
    expect(page).to have_content("Please enter a valid start month", count: 2)
    expect(page).to have_content("Please enter a valid start year", count: 2)
    expect(page).to have_content("Please enter a valid end day", count: 2)
    expect(page).to have_content("Please enter a valid end month", count: 2)
    expect(page).to have_content("Please enter a valid end year", count: 2)
    fill_in "link[start_day]", with: "31"
    fill_in "link[start_month]", with: "02"
    fill_in "link[start_year]", with: "2019"
    fill_in "link[end_day]", with: "31"
    fill_in "link[end_month]", with: "05"
    fill_in "link[end_year]", with: "2019"
    click_button "Save and continue"
    expect(page).to_not have_content("Please enter a valid start day")
    expect(page).to_not have_content("Please enter a valid start month", count: 2)
    expect(page).to_not have_content("Please enter a valid start year", count: 2)
    expect(page).to_not have_content("Please enter a valid end day", count: 2)
    expect(page).to_not have_content("Please enter a valid end month", count: 2)
    expect(page).to_not have_content("Please enter a valid end year", count: 2)
    expect(page).to have_content("Please enter a valid start date", count: 2)
    fill_in "link[start_month]", with: "01"
    click_button "Save and continue"
    expect(page).to have_content("Links to your data")
  end

  it "routes to the monthly datafiles page and check for errors" do
    choose option: "monthly"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
    expect(page).to have_content("Time period for this link")
    fill_in "link[url]", with: "http://www.example.com/test.csv"
    fill_in "link[name]", with: "Test datafile"
    click_button "Save and continue"
    expect(page).to have_content("Please enter a valid month", count: 2)
    expect(page).to have_content("Please enter a valid year", count: 2)
    fill_in "link[start_month]", with: "01"
    fill_in "link[start_year]", with: "2019"
    click_button "Save and continue"
    expect(page).to have_content("Links to your data")
  end

  it "routes to the quarterly datafiles page and check for errors" do
    choose option: "quarterly"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
    expect(page).to have_content("Quarter")
    fill_in "link[url]", with: "http://www.example.com/test.csv"
    fill_in "link[name]", with: "Test datafile"
    click_button "Save and continue"
    expect(page).to have_content("Please select a quarter", count: 2)
    expect(page).to have_content("Please enter a valid year", count: 2)
    choose option: "2"
    fill_in "link[start_year]", with: "2019"
    click_button "Save and continue"
    expect(page).to have_content("Links to your data")
  end

  it "routes to the yearly datafiles page and check for errors" do
    choose option: "annually"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
    expect(page).to have_content("Time period for this link")
    expect(page).to_not have_content("Month")
    expect(page).to have_content("Year")
    fill_in "link[url]", with: "http://www.example.com/test.csv"
    fill_in "link[name]", with: "Test datafile"
    click_button "Save and continue"
    expect(page).to have_content("Please enter a valid year", count: 2)
    fill_in "link[start_year]", with: "2019"
    click_button "Save and continue"
    expect(page).to have_content("Links to your data")
  end

  it "routes to the yearly (financial) datafiles page and check for errors" do
    choose option: "financial-year"
    click_button "Save and continue"
    expect(page).to have_content("Add a link to your data")
    expect(page).to have_content("Time period for this link")
    expect(page).to_not have_content("Month")
    expect(page).to have_content("Year")
    fill_in "link[url]", with: "http://www.example.com/test.csv"
    fill_in "link[name]", with: "Test datafile"
    click_button "Save and continue"
    expect(page).to have_content("Please enter a valid year", count: 2)
    fill_in "link[start_year]", with: "2019"
    click_button "Save and continue"
    expect(page).to have_content("Links to your data")
  end
end