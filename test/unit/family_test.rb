require File.dirname(__FILE__) + '/../test_helper'

class FamilyTest < ActiveSupport::TestCase

  context 'Barcodes' do
    should 'not allow the same barcode id to be assigned to two families' do
      @family = Family.forge(:barcode_id => '1234567890')
      @family2 = Family.create(Family.forgery_defaults.merge(:barcode_id => '1234567890'))
      assert @family2.errors.on(:barcode_id)
    end
    
    should 'not allow the same alternate barcode id to be assigned to two families' do
      @family = Family.forge(:alternate_barcode_id => '1234567890')
      @family2 = Family.create(Family.forgery_defaults.merge(:alternate_barcode_id => '1234567890'))
      assert @family2.errors.on(:alternate_barcode_id)
    end
    
    should 'not allow the same id to be assigned to a barcode_id and an alternate_barcode_id on different families' do
      # alternate was there first
      @family = Family.forge(:alternate_barcode_id => '1234567890')
      @family2 = Family.create(Family.forgery_defaults.merge(:barcode_id => '1234567890'))
      assert @family2.errors.on(:barcode_id)
      # main id was there first
      @family3 = Family.forge(:barcode_id => '9876543210')
      @family4 = Family.create(Family.forgery_defaults.merge(:alternate_barcode_id => '9876543210'))
      assert @family4.errors.on(:alternate_barcode_id)
    end
    
    should 'not allow a barcode_id and alternate_barcode_id to be the same' do
      # on existing record
      @family = Family.create(Family.forgery_defaults.merge(:barcode_id => '1234567890'))
      assert_valid @family
      @family.update_attributes(:alternate_barcode_id => '1234567890')
      assert @family.errors.on(:barcode_id)
      # on new record
      @family2 = Family.create(Family.forgery_defaults.merge(:barcode_id => '1231231231', :alternate_barcode_id => '1231231231'))
      assert @family2.errors.on(:barcode_id)
    end
    
    should 'allow both barcode_id and alternate_barcode_id to be nil' do
      @family = Family.create(Family.forgery_defaults.merge(:barcode_id => '', :alternate_barcode_id => nil))
      assert_equal nil, @family.errors.on(:barcode_id)
      assert_equal nil, @family.barcode_id
      assert_equal nil, @family.alternate_barcode_id
    end
  end
  
end
