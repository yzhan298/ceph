import { Component, OnInit, TemplateRef, ViewChild } from '@angular/core';

import * as _ from 'lodash';
import * as moment from 'moment';
import { BsModalRef, BsModalService } from 'ngx-bootstrap';

import { RbdService } from '../../../shared/api/rbd.service';
import { DeletionModalComponent } from '../../../shared/components/deletion-modal/deletion-modal.component';
import { TableComponent } from '../../../shared/datatable/table/table.component';
import { CellTemplate } from '../../../shared/enum/cell-template.enum';
import { ViewCacheStatus } from '../../../shared/enum/view-cache-status.enum';
import { CdTableAction } from '../../../shared/models/cd-table-action';
import { CdTableColumn } from '../../../shared/models/cd-table-column';
import { CdTableSelection } from '../../../shared/models/cd-table-selection';
import { ExecutingTask } from '../../../shared/models/executing-task';
import { FinishedTask } from '../../../shared/models/finished-task';
import { Permission } from '../../../shared/models/permissions';
import { CdDatePipe } from '../../../shared/pipes/cd-date.pipe';
import { AuthStorageService } from '../../../shared/services/auth-storage.service';
import { TaskListService } from '../../../shared/services/task-list.service';
import { TaskWrapperService } from '../../../shared/services/task-wrapper.service';
import { RbdTrashPurgeModalComponent } from '../rbd-trash-purge-modal/rbd-trash-purge-modal.component';
import { RbdTrashRestoreModalComponent } from '../rbd-trash-restore-modal/rbd-trash-restore-modal.component';

@Component({
  selector: 'cd-rbd-trash-list',
  templateUrl: './rbd-trash-list.component.html',
  styleUrls: ['./rbd-trash-list.component.scss'],
  providers: [TaskListService]
})
export class RbdTrashListComponent implements OnInit {
  @ViewChild(TableComponent)
  table: TableComponent;
  @ViewChild('expiresTpl')
  expiresTpl: TemplateRef<any>;
  @ViewChild('deleteTpl')
  deleteTpl: TemplateRef<any>;

  columns: CdTableColumn[];
  executingTasks: ExecutingTask[] = [];
  images: any;
  modalRef: BsModalRef;
  permission: Permission;
  retries: number;
  selection = new CdTableSelection();
  tableActions: CdTableAction[];
  viewCacheStatusList: any[];

  constructor(
    private authStorageService: AuthStorageService,
    private rbdService: RbdService,
    private modalService: BsModalService,
    private cdDatePipe: CdDatePipe,
    private taskListService: TaskListService,
    private taskWrapper: TaskWrapperService
  ) {
    this.permission = this.authStorageService.getPermissions().rbdImage;

    const restoreAction: CdTableAction = {
      permission: 'update',
      icon: 'fa-undo',
      click: () => this.restoreModal(),
      name: 'Restore'
    };
    const deleteAction: CdTableAction = {
      permission: 'delete',
      icon: 'fa-times',
      click: () => this.deleteModal(),
      name: 'Delete'
    };
    this.tableActions = [restoreAction, deleteAction];
  }

  ngOnInit() {
    this.columns = [
      {
        name: 'ID',
        prop: 'id',
        flexGrow: 1,
        cellTransformation: CellTemplate.executing
      },
      {
        name: 'Name',
        prop: 'name',
        flexGrow: 1
      },
      {
        name: 'Pool',
        prop: 'pool_name',
        flexGrow: 1
      },
      {
        name: 'Status',
        prop: 'deferment_end_time',
        flexGrow: 1,
        cellTemplate: this.expiresTpl
      },
      {
        name: 'Deleted At',
        prop: 'deletion_time',
        flexGrow: 1,
        pipe: this.cdDatePipe
      }
    ];

    this.taskListService.init(
      () => this.rbdService.listTrash(),
      (resp) => this.prepareResponse(resp),
      (images) => (this.images = images),
      () => this.onFetchError(),
      this.taskFilter,
      this.itemFilter,
      undefined
    );
  }

  prepareResponse(resp: any[]): any[] {
    let images = [];
    const viewCacheStatusMap = {};
    resp.forEach((pool) => {
      if (_.isUndefined(viewCacheStatusMap[pool.status])) {
        viewCacheStatusMap[pool.status] = [];
      }
      viewCacheStatusMap[pool.status].push(pool.pool_name);
      images = images.concat(pool.value);
    });

    const viewCacheStatusList = [];
    _.forEach(viewCacheStatusMap, (value: any, key) => {
      viewCacheStatusList.push({
        status: parseInt(key, 10),
        statusFor:
          (value.length > 1 ? 'pools ' : 'pool ') +
          '<strong>' +
          value.join('</strong>, <strong>') +
          '</strong>'
      });
    });
    this.viewCacheStatusList = viewCacheStatusList;
    images.forEach((image) => {
      image.cdIsExpired = moment().isAfter(image.deferment_end_time);
    });
    return images;
  }

  onFetchError() {
    this.table.reset(); // Disable loading indicator.
    this.viewCacheStatusList = [{ status: ViewCacheStatus.ValueException }];
  }

  itemFilter(entry, task) {
    return entry.id === task.metadata['image_id'];
  }

  taskFilter(task) {
    return ['rbd/trash/remove', 'rbd/trash/restore'].includes(task.name);
  }

  updateSelection(selection: CdTableSelection) {
    this.selection = selection;
  }

  restoreModal() {
    const initialState = {
      metaType: 'RBD',
      poolName: this.selection.first().pool_name,
      imageName: this.selection.first().name,
      imageId: this.selection.first().id
    };

    this.modalRef = this.modalService.show(RbdTrashRestoreModalComponent, { initialState });
  }

  deleteModal() {
    const poolName = this.selection.first().pool_name;
    const imageName = this.selection.first().name;
    const imageId = this.selection.first().id;
    const expiresAt = this.selection.first().deferment_end_time;

    this.modalRef = this.modalService.show(DeletionModalComponent, {
      initialState: {
        itemDescription: 'RBD',
        bodyTemplate: this.deleteTpl,
        bodyContext: { $implicit: expiresAt },
        submitActionObservable: () =>
          this.taskWrapper.wrapTaskAroundCall({
            task: new FinishedTask('rbd/trash/remove', {
              pool_name: poolName,
              image_id: imageId,
              image_name: imageName
            }),
            call: this.rbdService.removeTrash(poolName, imageId, imageName, true)
          })
      }
    });
  }

  isExpired(expiresAt): boolean {
    return moment().isAfter(expiresAt);
  }

  purgeModal() {
    this.modalService.show(RbdTrashPurgeModalComponent);
  }
}
