require 'spec_helper'

module Merit

  describe Profitable do

    let(:producer) do
      MustRunProducer.new(
        key:                       :coal,
        load_profile_key:          :industry_chp,
        output_capacity_per_unit:  1,
        marginal_costs:            2,
        availability:              0.95,
        number_of_units:           2,
        full_load_hours:           4,
        fixed_costs_per_unit:      30,
        fixed_om_costs_per_unit:   17
       )
    end

    let(:order) { Order.new }

    describe '#profitable' do
      it 'should be :profitable if revenue > total_costs' do
        producer.stub(:revenue) { 1000 }
        producer.stub(:total_costs) { 500 }
        expect(producer.profitability).to eql :profitable
      end
      it 'should be :conditionally_profitable if OPEX = <revenue < total_costs' do
        producer.stub(:revenue) { 500 }
        producer.stub(:total_costs) { 1000 }
        producer.stub(:operating_costs) { 300 }
        expect(producer.profitability).to eql :conditionally_profitable
      end
      it 'should be :unprofitable if revenue < OPEX' do
        producer.stub(:revenue) { 500 }
        producer.stub(:total_costs) { 1000 }
        producer.stub(:operating_costs) { 700 }
        expect(producer.profitability).to eql :unprofitable
      end
    end

    describe '#profit' do
      it 'should calculate correctly' do
        producer.stub(:revenue) { 1000 }
        producer.stub(:total_costs) { 500 }
        expect(producer.profit).to eql 500
      end
    end

    describe '#revenue' do
      context 'when the producer has either 0 units or no capacity' do
        it 'should return zero when it has 0 units' do
          producer.stub(:number_of_units) { 0 }
          expect(producer.revenue).to eql 0.0
        end
        it 'should return zero when capacity = 0' do
          producer.stub(:output_capacity_per_unit) { 0 }
          expect(producer.revenue).to eql 0.0
        end
      end
      context 'when the producer has >0 number of units and >0 capacity' do
        it 'should return the correct number' do
          order.stub(:price_curve) { LoadCurve.new(Array.new(8760,1)) }

          producer.order = order
          expect(producer.revenue).to be_within(0.1).of(1 * 2 * 4.0)
        end
      end
    end

    describe '#revenue_curve' do
      it 'should return a LoadCurve' do
        order.stub(:price_curve) { LoadCurve.new(Array.new(8760,1)) }

        producer.order = order
        expect(producer.revenue_curve).to be_a(LoadCurve)
        expect(producer.revenue_curve.to_a.first).to \
          be_within(0.01).of(8 / 8760.0)
      end
    end

    describe '#total_costs' do
      it 'should calculate correctly' do
        producer.stub(:fixed_costs) { 1000 }
        producer.stub(:variable_costs) { 500 }
        expect(producer.total_costs).to eql 1500
      end
    end

    describe '#variable_costs' do
      it 'should calculate correctly' do
        producer.stub(:production) { 1000 } #MWh
        expect(producer.variable_costs).to eql 2 * 1000
      end
    end

    describe '#fixed_costs' do
      it 'should calculate correctly' do
        expect(producer.fixed_costs).to eql 30 * 2
      end
    end

    describe '#fixed_om_costs' do
      it 'should calculate correctly' do
        expect(producer.fixed_om_costs).to eql 17 * 2
      end
    end

    describe '#operating_costs' do
      it 'should calculate correctly' do
        producer.stub(:variable_costs) { 17.4 }
        expect(producer.operating_costs).to eql 17 * 2 + 17.4
      end
    end

    describe '#profit_per_mwh_electricity' do
      before do
        @dispatchable = DispatchableProducer.new(
          key:                       :foo,
          marginal_costs:            50,
          output_capacity_per_unit:  1,
          number_of_units:           1,
          availability:              0.8,
          fixed_costs_per_unit:      100,
          fixed_om_costs_per_unit:   30
        )
        order.add @dispatchable
      end

      it 'should calculate correctly' do
        @dispatchable.stub(:production) { 1 }
        # marginal costs + fixed_costs_per_unit
        expect(@dispatchable.profit_per_mwh_electricity).to eql -150.0
      end

      it 'should return nil if the production is 0' do
        @dispatchable.stub(:production) { 0 }
        expect(@dispatchable.profit_per_mwh_electricity).to be_nil
      end
    end

  end # describe Producer

end # module Merit
