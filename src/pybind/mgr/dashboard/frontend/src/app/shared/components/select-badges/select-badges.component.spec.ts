import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ReactiveFormsModule, Validators } from '@angular/forms';

import { PopoverModule, TooltipModule } from 'ngx-bootstrap';

import { configureTestBed } from '../../../../testing/unit-test-helper';
import { SelectBadgesOption } from './select-badges-option.model';
import { SelectBadgesComponent } from './select-badges.component';

describe('SelectBadgesComponent', () => {
  let component: SelectBadgesComponent;
  let fixture: ComponentFixture<SelectBadgesComponent>;

  const selectOption = (filter: string) => {
    component.filter.setValue(filter);
    component.updateFilter();
    component.selectOption();
  };

  configureTestBed({
    declarations: [SelectBadgesComponent],
    imports: [PopoverModule.forRoot(), TooltipModule, ReactiveFormsModule]
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(SelectBadgesComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
    component.options = [
      { name: 'option1', description: '', selected: false },
      { name: 'option2', description: '', selected: false },
      { name: 'option3', description: '', selected: false }
    ];
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should add item', () => {
    component.data = [];
    component.triggerSelection(component.options[1]);
    expect(component.data).toEqual(['option2']);
  });

  it('should update selected', () => {
    component.data = ['option2'];
    component.ngOnChanges();
    expect(component.options[0].selected).toBe(false);
    expect(component.options[1].selected).toBe(true);
  });

  it('should remove item', () => {
    component.options.map((option) => {
      option.selected = true;
      return option;
    });
    component.data = ['option1', 'option2', 'option3'];
    component.removeItem('option1');
    expect(component.data).toEqual(['option2', 'option3']);
  });

  it('should not remove item that is not selected', () => {
    component.options[0].selected = true;
    component.data = ['option1'];
    component.removeItem('option2');
    expect(component.data).toEqual(['option1']);
  });

  describe('filter values', () => {
    beforeEach(() => {
      component.ngOnInit();
    });

    it('shows all options with no value set', () => {
      expect(component.filteredOptions).toEqual(component.options);
    });

    it('shows one option that it filtered for', () => {
      component.filter.setValue('2');
      component.updateFilter();
      expect(component.filteredOptions).toEqual([component.options[1]]);
    });

    it('shows all options after selecting something', () => {
      component.filter.setValue('2');
      component.updateFilter();
      component.selectOption();
      expect(component.filteredOptions).toEqual(component.options);
    });

    it('is not able to create by default with no value set', () => {
      component.updateFilter();
      expect(component.isCreatable()).toBeFalsy();
    });

    it('is not able to create by default with a value set', () => {
      component.filter.setValue('2');
      component.updateFilter();
      expect(component.isCreatable()).toBeFalsy();
    });
  });

  describe('automatically add selected options if not in options array', () => {
    beforeEach(() => {
      component.data = ['option1', 'option4'];
      expect(component.options.length).toBe(3);
    });

    const expectedResult = () => {
      expect(component.options.length).toBe(4);
      expect(component.options[3]).toEqual(new SelectBadgesOption(true, 'option4', ''));
    };

    it('with no extra settings', () => {
      component.ngOnInit();
      expectedResult();
    });

    it('with custom badges', () => {
      component.customBadges = true;
      component.ngOnInit();
      expectedResult();
    });

    it('with limit higher than selected', () => {
      component.selectionLimit = 3;
      component.ngOnInit();
      expectedResult();
    });

    it('with limit equal to selected', () => {
      component.selectionLimit = 2;
      component.ngOnInit();
      expectedResult();
    });

    it('with limit lower than selected', () => {
      component.selectionLimit = 1;
      component.ngOnInit();
      expectedResult();
    });
  });

  describe('sorted array and options', () => {
    beforeEach(() => {
      component.customBadges = true;
      component.customBadgeValidators = [Validators.pattern('[A-Za-z0-9_]+')];
      component.data = ['c', 'b'];
      component.options = [
        new SelectBadgesOption(true, 'd', ''),
        new SelectBadgesOption(true, 'a', '')
      ];
      component.ngOnInit();
    });

    it('has a sorted selection', () => {
      expect(component.data).toEqual(['a', 'b', 'c', 'd']);
    });

    it('has a sorted options', () => {
      const sortedOptions = [
        new SelectBadgesOption(true, 'a', ''),
        new SelectBadgesOption(true, 'b', ''),
        new SelectBadgesOption(true, 'c', ''),
        new SelectBadgesOption(true, 'd', '')
      ];
      expect(component.options).toEqual(sortedOptions);
    });

    it('has a sorted selection after adding an item', () => {
      selectOption('block');
      expect(component.data).toEqual(['a', 'b', 'block', 'c', 'd']);
    });

    it('has a sorted options after adding an item', () => {
      selectOption('block');
      const sortedOptions = [
        new SelectBadgesOption(true, 'a', ''),
        new SelectBadgesOption(true, 'b', ''),
        new SelectBadgesOption(true, 'block', ''),
        new SelectBadgesOption(true, 'c', ''),
        new SelectBadgesOption(true, 'd', '')
      ];
      expect(component.options).toEqual(sortedOptions);
    });
  });

  describe('with custom options', () => {
    beforeEach(() => {
      component.customBadges = true;
      component.customBadgeValidators = [Validators.pattern('[A-Za-z0-9_]+')];
      component.ngOnInit();
    });

    it('is not able to create with no value set', () => {
      component.updateFilter();
      expect(component.isCreatable()).toBeFalsy();
    });

    it('is able to create with a valid value set', () => {
      component.filter.setValue('2');
      component.updateFilter();
      expect(component.isCreatable()).toBeTruthy();
    });

    it('is not able to create with a value set that already exist', () => {
      component.filter.setValue('option2');
      component.updateFilter();
      expect(component.isCreatable()).toBeFalsy();
    });

    it('adds custom option', () => {
      selectOption('customOption');
      expect(component.options[0]).toEqual({
        name: 'customOption',
        description: '',
        selected: true
      });
      expect(component.options.length).toBe(4);
      expect(component.data).toEqual(['customOption']);
    });

    it('will not add an option that did not pass the validation', () => {
      selectOption(' this does not pass ');
      expect(component.options.length).toBe(3);
      expect(component.data).toEqual([]);
      expect(component.filter.invalid).toBeTruthy();
    });

    it('removes custom item selection by name', () => {
      selectOption('customOption');
      component.removeItem('customOption');
      expect(component.data).toEqual([]);
      expect(component.options.length).toBe(4);
      expect(component.options[0]).toEqual({
        name: 'customOption',
        description: '',
        selected: false
      });
    });

    it('will not add an option that is already there', () => {
      selectOption('option2');
      expect(component.options.length).toBe(3);
      expect(component.data).toEqual(['option2']);
    });

    it('will not add an option twice after each other', () => {
      selectOption('onlyOnce');
      expect(component.data).toEqual(['onlyOnce']);
      selectOption('onlyOnce');
      expect(component.data).toEqual([]);
      selectOption('onlyOnce');
      expect(component.data).toEqual(['onlyOnce']);
      expect(component.options.length).toBe(4);
    });
  });

  describe('if the selection limit is reached', function() {
    beforeEach(() => {
      component.selectionLimit = 2;
      component.triggerSelection(component.options[0]);
      component.triggerSelection(component.options[1]);
    });

    it('will not select more options', () => {
      component.triggerSelection(component.options[2]);
      expect(component.data).toEqual(['option1', 'option2']);
    });

    it('will unselect options that are selected', () => {
      component.triggerSelection(component.options[1]);
      expect(component.data).toEqual(['option1']);
    });
  });
});
