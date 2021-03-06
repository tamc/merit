require 'spec_helper'

module Merit

  describe User do

    let(:user){ User.new(key: :total_demand) }
 
    describe '#new' do

      it 'should accept a load curve with a load profile' do
        expect(->{ user }).to_not raise_error
      end

    end # describe #new

    describe '#load_curve' do

      context 'no total_consumption given' do
        it 'should return a load_curve for it' do
          expect(->{ user.load_curve }).to raise_error(UnknownDemandError)
        end
      end

      context 'total_consumption given' do
        it 'should return a load curve' do
          user.total_consumption = 300 * 10**9
          expect(->{ user.load_curve }).to_not raise_error
        end
      end

    end #describe #load_curve

    describe '#load_at' do
      it 'should return a nice number' do
        user.total_consumption = 300 * 10**9
        expect(user.load_at(117)).to be > 0
      end
    end

    describe '#load_between' do
      before { user.total_consumption = 210 * 10 ** 9 }

      it 'should return the total load between the two points' do
        expect(user.load_between(50, 52)).to be_within(0.01).of(
          user.load_at(50) + user.load_at(51) + user.load_at(52)
        )
      end
    end

  end #describe User

end #module Merit
