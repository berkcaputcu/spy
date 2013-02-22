require "spy/core_ext/marshal"
require "spy/agency"
require "spy/constant"
require "spy/double"
require "spy/nest"
require "spy/subroutine"
require "spy/version"

module Spy
  SECRET_SPY_KEY = Object.new
  private_constant :SECRET_SPY_KEY

  class << self
    # create a spy on given object
    # @param base_object
    # @param method_names *[Hash,Symbol] will spy on these methods and also set default return values
    # @return [Subroutine, Array<Subroutine>]
    def on(base_object, *method_names)
      spies = method_names.map do |method_name|
        create_and_hook_spy(base_object, method_name)
      end.flatten

      spies.size > 1 ? spies : spies.first
    end

    # removes the spy from the from the given object
    # @param base_object
    # @param method_names *[Symbol]
    # @return [Subroutine, Array<Subroutine>]
    def off(base_object, *method_names)
      removed_spies = method_names.map do |method_name|
        spy = Subroutine.get(base_object, method_name)
        if spy
          spy.unhook
        else
          raise "Spy was not found"
        end
      end

      removed_spies.size > 1 ? removed_spies : removed_spies.first
    end

    def on_any_instance_of(base_class, *method_names)
    end

    # create a stub for constants on given module
    # @param base_module [Module]
    # @param constant_names *[Symbol, Hash]
    # @return [Constant, Array<Constant>]
    def on_const(base_module, *constant_names)
      if base_module.is_a?(Hash) || base_module.is_a?(Symbol)
        constant_names.unshift(base_module)
        base_module = Object
      end
      spies = constant_names.map do |constant_name|
        case constant_name
        when String, Symbol
          Constant.on(base_module, constant_name)
        when Hash
          constant_name.map do |name, result|
            on_const(base_module, name).and_return(result)
          end
        else
          raise ArgumentError.new "#{constant_name.class} is an invalid input, #on only accepts String, Symbol, and Hash"
        end
      end.flatten

      spies.size > 1 ? spies : spies.first
    end

    # removes stubs from given module
    # @param base_module [Module]
    # @param constant_names *[Symbol]
    # @return [Constant, Array<Constant>]
    def off_const(base_module, *constant_names)
      if base_module.is_a?(Hash) || base_module.is_a?(Symbol)
        constant_names.unshift(base_module)
        base_module = Object
      end

      spies = constant_names.map do |constant_name|
        case constant_name
        when String, Symbol
          Constant.off(base_module, constant_name)
        when Hash
          constant_name.map do |name, result|
            off_const(base_module, name).and_return(result)
          end
        else
          raise ArgumentError.new "#{constant_name.class} is an invalid input, #on only accepts String, Symbol, and Hash"
        end
      end.flatten

      spies.size > 1 ? spies : spies.first
    end

    # unhook all methods
    def teardown
      Agency.instance.dissolve!
    end

    # returns a double
    # (see Double#initizalize)
    def double(*args)
      Double.new(*args)
    end

    # retrieve the spy from an object
    # @param base_object
    # @param method_names *[Symbol]
    # @return [Subroutine, Array<Subroutine>]
    def get(base_object, *method_names)
      spies = method_names.map do |method_name|
        Subroutine.get(base_object, method_name)
      end

      spies.size > 1 ? spies : spies.first
    end

    # retrieve the constant spies from an object
    # @param base_module
    # @param constant_names *[Symbol]
    # @return [Constant, Array<Constant>]
    def get_const(base_module, *constant_names)
      if base_module.is_a?(Hash) || base_module.is_a?(Symbol)
        constant_names.unshift(base_module)
        base_module = Object
      end

      spies = constant_names.map do |constant_name|
        Constant.get(base_module, constant_name)
      end

      spies.size > 1 ? spies : spies.first
    end

    private

    def create_and_hook_spy(base_object, method_name, opts = {})
      case method_name
      when String, Symbol
        Subroutine.new(base_object, method_name).hook(opts)
      when Hash
        method_name.map do |name, result|
          create_and_hook_spy(base_object, name, opts).and_return(result)
        end
      else
        raise ArgumentError.new "#{method_name.class} is an invalid input, #on only accepts String, Symbol, and Hash"
      end
    end
  end
end
