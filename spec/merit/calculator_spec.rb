require 'spec_helper'

module Merit
  describe 'Calculations' do
    def make_order
      Order.new.tap do |order|
        order.add(DispatchableProducer.new(
          key:                       :dispatchable,
          marginal_costs:            13.999791,
          output_capacity_per_unit:  0.1,
          number_of_units:           1,
          availability:              0.89,
          fixed_costs_per_unit:      222.9245208,
          fixed_om_costs_per_unit:   35.775
        ))

        order.add(VolatileProducer.new(
          key:                       :volatile,
          marginal_costs:            19.999791,
          load_profile_key:          :industry_chp,
          output_capacity_per_unit:  0.1,
          availability:              0.95,
          number_of_units:           1,
          fixed_costs_per_unit:      222.9245208,
          fixed_om_costs_per_unit:   35.775,
          full_load_hours:           1000
        ))

        order.add(VolatileProducer.new(
          key:                       :volatile_two,
          marginal_costs:            21.21,
          load_profile_key:          :solar_pv,
          output_capacity_per_unit:  0.1,
          availability:              0.95,
          number_of_units:           1,
          fixed_costs_per_unit:      222.9245208,
          fixed_om_costs_per_unit:   35.775,
          full_load_hours:           1000
        ))

        order.add(User.new(key: :total_demand, total_consumption: 6.4e6))
      end
    end

    let(:order)        { make_order }
    let(:volatile)     { order.participant(:volatile) }
    let(:volatile_two) { order.participant(:volatile_two) }
    let(:dispatchable) { order.participant(:dispatchable) }

    context 'with an excess of demand' do
      before { Calculator.new.calculate(order) }

      it 'sets the load profile values of the first producer' do
        load_value = dispatchable.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(dispatchable.max_load_at(0))
      end

      it 'sets the load profile values of the second producer' do
        load_value = volatile.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(volatile.max_load_at(0))
      end

      it 'sets the load profile values of the third producer' do
        load_value = volatile_two.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(volatile_two.max_load_at(0))
      end

      it 'assigns the price setting producer with nothing' do
        expect(order.price_setting_producers).to eql Array.new(POINTS)
      end
    end

    context 'with an excess of supply' do
      before { dispatchable.instance_variable_set(:@number_of_units, 2) }
      before { order.calculate(Calculator.new) }

      it 'sets the load profile values of the first producer' do
        load_value = dispatchable.load_curve.get(0)

        demand = order.users.first.load_at(0)
        demand -= volatile.max_load_at(0)
        demand -= volatile_two.max_load_at(0)

        expect(load_value).to_not be_nil
        expect(load_value).to be_within(0.01).of(demand)
      end

      it 'sets the load profile values of the second producer' do
        load_value = volatile.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(volatile.max_load_at(0))
      end

      it 'sets the load profile values of the third producer' do
        load_value = volatile_two.load_curve.get(0)

        expect(load_value).to_not be_nil
        expect(load_value).to eql(volatile_two.max_load_at(0))
      end

      it 'assigns the price setting producer with nothing' do
        expect(order.price_setting_producers).to eql Array.new(POINTS)
      end
    end

    context 'with an overly excess of supply' do
      before { volatile.instance_variable_set(:@number_of_units, 10**9) }
      before { order.calculate(Calculator.new) }

      it 'sets the load profile values of the first producer' do
        load_value = dispatchable.load_curve.get(0)

        expect(load_value).to eql 0.0
      end

      it 'sets the load profile values of the second producer' do
        load_value = volatile.load_curve.get(0)

        expect(load_value).to eql(volatile.max_load_at(0))
      end

      it 'sets the load profile values of the third producer' do
        load_value = volatile_two.load_curve.get(0)

        expect(load_value).to be_within(0.001).of(0.0)
      end

      it 'assigns the price setting producer with nothing' do
        expect(order.price_setting_producers).to eql \
          Array.new(POINTS, dispatchable)
      end
    end

    describe 'with QuantizingCalculator' do
      it 'should set a value for each load point' do
        # Set an excess of demand so that the dispatchable is running
        # all the time.
        order.users.first.total_consumption = 6.4e7

        QuantizingCalculator.new.calculate(order)

        values = order.participant(:dispatchable).load_curve.
          instance_variable_get(:@values).compact

        expect(values).to have(Merit::POINTS).members
      end

      it 'raises an error if using a chunk size of 1' do
        expect { QuantizingCalculator.new(1) }.
          to raise_error(InvalidChunkSize)
      end
    end # with QuantizingCalculator

    describe 'with AveragingCalculator' do
      it 'should set a value for each nth load point' do
        # Set an excess of demand so that the dispatchable is running
        # all the time.
        order.users.first.total_consumption = 6.4e7

        AveragingCalculator.new.calculate(order)

        values = order.participant(:dispatchable).load_curve.
          instance_variable_get(:@values).compact

        expect(values).to have(Merit::POINTS / 8).members
      end

      it 'raises an error if using a chunk size of 1' do
        expect { AveragingCalculator.new(1) }.
          to raise_error(InvalidChunkSize)
      end

      it "doesn't over-assign load" do
        order.users.first.total_consumption = 1.0e6

        # Explicitly tests assigning the "remaining" demand in
        # AveragingCalulator#compute_loads!
        expect {
          AveragingCalculator.new.calculate(order)
        }.to_not raise_error
      end

      it "only assigns demand when some is present" do
        # Set zero demand so that each producers receives zero. This
        # explicitly tests the "break" in AveragingCalculator#compute_loads!
        order.users.first.total_consumption = 0.0

        expect {
          AveragingCalculator.new.calculate(order)
        }.to_not raise_error
      end
    end # with AveragingCalculator

    context 'when producer order is incorrect' do
      # Impossible with the current Order class, but serves as a regression
      # test.
      it 'raises an error' do
        order.stub(:producers).and_return([
          volatile, dispatchable, volatile_two])

        expect { Calculator.new.calculate(order) }.
          to raise_error(IncorrectProducerOrder)
      end
    end

  end # Calculator
end # Merit
